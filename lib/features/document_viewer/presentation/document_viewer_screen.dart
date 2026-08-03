import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_controller.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';
import 'package:forkumentos/shared/providers/document_content_provider.dart';
import 'package:forkumentos/shared/widgets/mapping_aware_paragraph.dart';

const _zoomSteps = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];
const _defaultZoomStepIndex = 2;
const _pageSpacing = 24.0;
const _viewportPadding = 24.0;

// Tamaño de cuerpo de reserva, en puntos, para documentos que no declaran
// ninguno en `w:docDefaults`. Es el "Normal" de Word/Office modernos; cuando
// el DOCX sí lo declara (el caso habitual) manda el del documento.
const _fallbackBodyFontSizePoints = 11.0;

// Márgenes de celda por defecto de Word (`w:tblCellMar`): 108 twips a
// izquierda y derecha, cero arriba y abajo.
const _tableCellPaddingPoints = 5.4;

enum _ZoomMode { manual, fitWidth, fitPage }

final class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({
    required this.documentPath,
    required this.isSourceLoading,
    this.sourceErrorMessage,
    this.showToolbar = true,
    this.controller,
    this.documentOverride,
    this.viewerOverlay,
    this.focusPageIndex,
    this.focusToken = 0,
    super.key,
  });

  final String? documentPath;
  final bool isSourceLoading;
  final String? sourceErrorMessage;
  final bool showToolbar;
  final DocumentViewerController? controller;
  final AsyncValue<Document?>? documentOverride;
  final DocumentViewerOverlay? viewerOverlay;
  final int? focusPageIndex;
  final int focusToken;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

final class _DocumentViewerScreenState
    extends ConsumerState<DocumentViewerScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewportKey = GlobalKey();

  List<GlobalKey> _pageKeys = <GlobalKey>[];
  int _currentPageIndex = 0;
  _ZoomMode _zoomMode = _ZoomMode.manual;
  int _manualZoomStepIndex = _defaultZoomStepIndex;
  double _lastKnownScale = _zoomSteps[_defaultZoomStepIndex];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _attachController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant DocumentViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      _attachController(widget.controller);
    }
    if (oldWidget.documentPath != widget.documentPath) {
      _currentPageIndex = 0;
      _zoomMode = _ZoomMode.manual;
      _manualZoomStepIndex = _defaultZoomStepIndex;
      _lastKnownScale = _zoomSteps[_defaultZoomStepIndex];
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _publishViewState();
    }

    if (widget.focusToken != oldWidget.focusToken &&
        widget.focusPageIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _goToPage(widget.focusPageIndex!);
      });
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _attachController(DocumentViewerController? controller) {
    controller?.attach(
      zoomIn: _zoomIn,
      zoomOut: _zoomOut,
      fitWidth: _selectFitWidth,
      fitPage: _selectFitPage,
      setScale: _setScale,
    );
    _publishViewState();
  }

  void _publishViewState() {
    widget.controller?.updateViewState(
      zoomPercentage: (_lastKnownScale * 100).round(),
      isFitWidth: _zoomMode == _ZoomMode.fitWidth,
      isFitPage: _zoomMode == _ZoomMode.fitPage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Document?> documentState;
    if (widget.documentOverride != null) {
      documentState = widget.documentOverride!;
    } else if (widget.documentPath == null) {
      documentState = const AsyncData<Document?>(null);
    } else {
      documentState = ref.watch(documentContentProvider(widget.documentPath!));
    }

    final sourceErrorMessage = widget.sourceErrorMessage;
    if (sourceErrorMessage != null && widget.documentOverride == null) {
      return _CenteredStatus(
        title: 'No se pudo preparar la vista del documento.',
        description: sourceErrorMessage,
        isError: true,
      );
    }

    if (widget.isSourceLoading) {
      return const _CenteredStatus(
        title: 'Cargando documento...',
        showProgress: true,
      );
    }

    final documentPath = widget.documentPath;
    if (documentPath == null && widget.documentOverride == null) {
      return const _CenteredStatus(
        title: 'Todavía no importaste una plantilla DOCX para este proyecto.',
        description:
            'Importa una plantilla en la vista de plantilla del proyecto '
            'para visualizar su contenido aquí.',
      );
    }

    if (documentState.isLoading && documentState.valueOrNull == null) {
      return const _CenteredStatus(
        title: 'Cargando documento...',
        showProgress: true,
      );
    }

    if (documentState.hasError && documentState.valueOrNull == null) {
      return _CenteredStatus(
        title: 'No se pudo cargar el documento.',
        description: _resolveDocumentErrorMessage(documentState.error),
        isError: true,
      );
    }

    final document = documentState.valueOrNull;
    if (document == null) {
      return const _CenteredStatus(
        title: 'No se pudo cargar el documento.',
        description: 'Inténtalo nuevamente desde la vista de plantilla.',
        isError: true,
      );
    }

    _ensurePageKeys(document.pages.length);

    final pageCount = document.pages.length;
    final currentPageNumber = pageCount == 0 ? 0 : _currentPageIndex + 1;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.showToolbar)
            _DocumentToolbar(
              currentPageNumber: currentPageNumber,
              pageCount: pageCount,
              canGoToPreviousPage: _currentPageIndex > 0,
              canGoToNextPage: _currentPageIndex < pageCount - 1,
              onPreviousPage: () => _goToPage(_currentPageIndex - 1),
              onNextPage: () => _goToPage(_currentPageIndex + 1),
            ),
          if (document.omissions.isNotEmpty) ...<Widget>[
            if (widget.showToolbar) const SizedBox(height: 8),
            _InlineInfo(message: _buildOmissionsMessage(document.omissions)),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final effectiveScale = _resolveEffectiveScale(
                  document: document,
                  viewportConstraints: constraints,
                );
                _scheduleScaleUpdate(effectiveScale);

                final widestPageWidth = document.pages
                    .map(
                      (DocumentPage page) => page.widthPoints * effectiveScale,
                    )
                    .fold<double>(0, math.max);
                final contentWidth = math.max(
                  constraints.maxWidth,
                  widestPageWidth + (_viewportPadding * 2),
                );

                return Listener(
                  onPointerSignal: (event) {
                    if (event is! PointerScrollEvent) return;
                    if (!HardwareKeyboard.instance.isControlPressed) return;
                    if (event.scrollDelta.dy < 0) {
                      _zoomIn();
                    } else if (event.scrollDelta.dy > 0) {
                      _zoomOut();
                    }
                  },
                  child: ColoredBox(
                    key: _scrollViewportKey,
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: contentWidth,
                        child: Scrollbar(
                          controller: _scrollController,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: _viewportPadding,
                                vertical: _viewportPadding,
                              ),
                              child: Column(
                                children: _pageSheetChildren(
                                  document,
                                  effectiveScale,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _pageSheetChildren(Document document, double scale) {
    final children = <Widget>[];
    // Absolute, page-agnostic offset (see the DocumentTextPath doc comment):
    // advances by each page's block count so paragraph paths built further
    // down never need to know which page they're on.
    var rootBlockOffset = 0;
    for (var index = 0; index < document.pages.length; index++) {
      children.add(
        Align(
          key: _pageKeys[index],
          alignment: Alignment.topCenter,
          child: _DocumentPageSheet(
            rootBlockOffset: rootBlockOffset,
            page: document.pages[index],
            header: document.header,
            footer: document.footer,
            scale: scale,
            viewerOverlay: widget.viewerOverlay,
          ),
        ),
      );
      rootBlockOffset += document.pages[index].blocks.length;
      if (index < document.pages.length - 1) {
        children.add(const SizedBox(height: _pageSpacing));
      }
    }
    return children;
  }

  void _scheduleScaleUpdate(double scale) {
    if ((scale - _lastKnownScale).abs() < 0.001) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastKnownScale = scale;
      });
      _publishViewState();
    });
  }

  void _ensurePageKeys(int pageCount) {
    if (_pageKeys.length == pageCount) {
      return;
    }

    _pageKeys = List<GlobalKey>.generate(pageCount, (_) => GlobalKey());
    if (_currentPageIndex >= pageCount) {
      _currentPageIndex = pageCount == 0 ? 0 : pageCount - 1;
    }
  }

  void _onScroll() {
    final viewportContext = _scrollViewportKey.currentContext;
    if (viewportContext == null || _pageKeys.isEmpty) {
      return;
    }

    final viewportRenderObject = viewportContext.findRenderObject();
    if (viewportRenderObject is! RenderBox) {
      return;
    }

    final viewportTop = viewportRenderObject.localToGlobal(Offset.zero).dy;
    var closestIndex = _currentPageIndex;
    var closestDistance = double.infinity;

    for (var index = 0; index < _pageKeys.length; index++) {
      final pageContext = _pageKeys[index].currentContext;
      if (pageContext == null) {
        continue;
      }

      final pageRenderObject = pageContext.findRenderObject();
      if (pageRenderObject is! RenderBox) {
        continue;
      }

      final pageTop = pageRenderObject.localToGlobal(Offset.zero).dy;
      final distance = (pageTop - viewportTop).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    }

    if (closestIndex == _currentPageIndex || !mounted) {
      return;
    }

    setState(() {
      _currentPageIndex = closestIndex;
    });
  }

  Future<void> _goToPage(int targetIndex) async {
    if (targetIndex < 0 || targetIndex >= _pageKeys.length) {
      return;
    }

    final pageContext = _pageKeys[targetIndex].currentContext;
    if (pageContext == null) {
      return;
    }

    // `keepVisibleAtStart` only ever moves the offset *backward* (its
    // `ensureVisible` implementation clamps the target to the current
    // position whenever the computed target is greater than `pixels`), so it
    // silently no-ops for the common case of a target further down than the
    // current scroll position. The default `explicit` policy with alignment
    // 0 aligns the page's top edge to the viewport's top in both directions.
    await Scrollable.ensureVisible(
      pageContext,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _currentPageIndex = targetIndex;
    });
  }

  void _selectFitWidth() {
    if (_zoomMode == _ZoomMode.fitWidth) {
      return;
    }

    _updateZoomPreservingPosition(() {
      _zoomMode = _ZoomMode.fitWidth;
    });
  }

  void _selectFitPage() {
    if (_zoomMode == _ZoomMode.fitPage) {
      return;
    }

    _updateZoomPreservingPosition(() {
      _zoomMode = _ZoomMode.fitPage;
    });
  }

  void _zoomIn() {
    final baseStepIndex = _zoomMode == _ZoomMode.manual
        ? _manualZoomStepIndex
        : _nearestZoomStepIndex(_lastKnownScale);
    final nextStepIndex = math.min(baseStepIndex + 1, _zoomSteps.length - 1);

    _updateZoomPreservingPosition(() {
      _zoomMode = _ZoomMode.manual;
      _manualZoomStepIndex = nextStepIndex;
    });
  }

  void _zoomOut() {
    final baseStepIndex = _zoomMode == _ZoomMode.manual
        ? _manualZoomStepIndex
        : _nearestZoomStepIndex(_lastKnownScale);
    final nextStepIndex = math.max(baseStepIndex - 1, 0);

    _updateZoomPreservingPosition(() {
      _zoomMode = _ZoomMode.manual;
      _manualZoomStepIndex = nextStepIndex;
    });
  }

  void _setScale(double scale) {
    final clamped = scale.clamp(_zoomSteps.first, _zoomSteps.last);
    final nextStepIndex = _nearestZoomStepIndex(clamped);

    _updateZoomPreservingPosition(() {
      _zoomMode = _ZoomMode.manual;
      _manualZoomStepIndex = nextStepIndex;
    });
  }

  int _nearestZoomStepIndex(double scale) {
    var selectedIndex = 0;
    var selectedDistance = double.infinity;

    for (var index = 0; index < _zoomSteps.length; index++) {
      final distance = (_zoomSteps[index] - scale).abs();
      if (distance < selectedDistance) {
        selectedDistance = distance;
        selectedIndex = index;
      }
    }

    return selectedIndex;
  }

  void _updateZoomPreservingPosition(VoidCallback updateZoom) {
    final previousFraction = _captureScrollFraction();

    setState(updateZoom);
    _publishViewState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _restoreScrollFraction(previousFraction);
    });
  }

  double _captureScrollFraction() {
    if (!_scrollController.hasClients) {
      return 0;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      return 0;
    }

    final fraction = _scrollController.offset / maxExtent;
    return fraction.clamp(0, 1).toDouble();
  }

  void _restoreScrollFraction(double fraction) {
    if (!_scrollController.hasClients) {
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    final clampedFraction = fraction.clamp(0, 1).toDouble();
    final targetOffset = (maxExtent * clampedFraction).clamp(0, maxExtent);
    _scrollController.jumpTo(targetOffset.toDouble());
  }

  double _resolveEffectiveScale({
    required Document document,
    required BoxConstraints viewportConstraints,
  }) {
    if (document.pages.isEmpty) {
      return _zoomSteps[_manualZoomStepIndex];
    }

    if (_zoomMode == _ZoomMode.manual) {
      return _zoomSteps[_manualZoomStepIndex];
    }

    final availableWidth = _atLeastOne(
      viewportConstraints.maxWidth - (_viewportPadding * 2),
    );

    if (_zoomMode == _ZoomMode.fitWidth) {
      final widestPage = document.pages
          .map((page) => page.widthPoints)
          .fold<double>(0, math.max);
      final fitScale = availableWidth / _atLeastOne(widestPage);
      return fitScale.clamp(_zoomSteps.first, _zoomSteps.last);
    }

    final currentPageIndex = _currentPageIndex.clamp(
      0,
      document.pages.length - 1,
    );
    final currentPage = document.pages[currentPageIndex];
    final availableHeight = _atLeastOne(
      viewportConstraints.maxHeight - (_viewportPadding * 2),
    );
    final widthScale = availableWidth / _atLeastOne(currentPage.widthPoints);
    final heightScale = availableHeight / _atLeastOne(currentPage.heightPoints);
    final fitScale = math.min(widthScale, heightScale);
    return fitScale.clamp(_zoomSteps.first, _zoomSteps.last);
  }

  double _atLeastOne(double value) {
    if (value < 1) {
      return 1;
    }
    return value;
  }
}

String _resolveDocumentErrorMessage(Object? error) {
  if (error is DocumentContentException) {
    return error.message;
  }
  return 'No se pudo cargar la vista del documento.';
}

String _buildOmissionsMessage(Set<DocumentOmission> omissions) {
  final labels = <String>[
    for (final omission
        in omissions.toList()..sort((a, b) => a.index - b.index))
      switch (omission) {
        DocumentOmission.image => 'imágenes',
        DocumentOmission.headerFooter => 'encabezados o pies de página',
        DocumentOmission.footnote => 'notas al pie',
      },
  ];

  if (labels.isEmpty) {
    return '';
  }

  final listedLabels = labels.length == 1
      ? labels.first
      : '${labels.sublist(0, labels.length - 1).join(', ')} y ${labels.last}';
  return 'Este documento contiene '
      '$listedLabels que no se muestran en esta vista previa.';
}

final class _DocumentToolbar extends StatelessWidget {
  const _DocumentToolbar({
    required this.currentPageNumber,
    required this.pageCount,
    required this.canGoToPreviousPage,
    required this.canGoToNextPage,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int currentPageNumber;
  final int pageCount;
  final bool canGoToPreviousPage;
  final bool canGoToNextPage;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: 'Página anterior',
              onPressed: canGoToPreviousPage ? onPreviousPage : null,
              icon: const Icon(Icons.navigate_before),
            ),
            IconButton(
              tooltip: 'Página siguiente',
              onPressed: canGoToNextPage ? onNextPage : null,
              icon: const Icon(Icons.navigate_next),
            ),
            const SizedBox(width: 8),
            Text('Página $currentPageNumber de $pageCount'),
          ],
        ),
      ),
    );
  }
}

/// Una hoja del documento, maquetada en PUNTOS y escalada al pintar.
///
/// Maquetar a tamaño real y escalar después (en vez de multiplicar cada
/// medida por el zoom) es lo que hace Word: los saltos de línea, la posición
/// de cada párrafo y el alto de la hoja son idénticos al 50% y al 200%, y
/// solo cambia el tamaño con el que se dibujan.
final class _DocumentPageSheet extends StatelessWidget {
  const _DocumentPageSheet({
    required this.rootBlockOffset,
    required this.page,
    required this.header,
    required this.footer,
    required this.scale,
    this.viewerOverlay,
  });

  final int rootBlockOffset;
  final DocumentPage page;
  final List<DocumentBlock> header;
  final List<DocumentBlock> footer;
  final double scale;
  final DocumentViewerOverlay? viewerOverlay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // La hoja es papel simulado, no chrome de la app: su tipografía no debe
    // moverse si el usuario cambia el tema de la interfaz, por eso parte de
    // un TextStyle explícito en vez de Theme.of(context).textTheme. El
    // tamaño y la familia reales los aporta cada run del DOCX; esto es solo
    // el respaldo para documentos que no declaran ninguno.
    const bodyStyle = TextStyle(
      fontSize: _fallbackBodyFontSizePoints,
      color: Colors.black,
    );

    final margins = page.margins;
    final contentHeightPoints = math.max<double>(
      0,
      page.heightPoints - margins.topPoints - margins.bottomPoints,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: _ScaledPage(
        scale: scale,
        child: SizedBox(
          width: page.widthPoints,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Banda del margen superior. En Word el encabezado vive DENTRO
              // del margen, anclado a `w:pgMar/@header` desde el borde de la
              // hoja, y empuja el cuerpo hacia abajo solo si no le cabe.
              _PageBand(
                minHeightPoints: margins.topPoints,
                padding: EdgeInsets.only(
                  top: margins.headerDistancePoints,
                  left: margins.leftPoints,
                  right: margins.rightPoints,
                ),
                alignment: Alignment.topLeft,
                child: _blockColumn(
                  blocks: header,
                  region: DocumentTextRegion.header,
                  rootBlockOffset: 0,
                  textStyle: bodyStyle,
                ),
              ),
              _PageBand(
                minHeightPoints: contentHeightPoints,
                padding: EdgeInsets.only(
                  left: margins.leftPoints,
                  right: margins.rightPoints,
                ),
                alignment: Alignment.topLeft,
                child: _blockColumn(
                  blocks: page.blocks,
                  region: DocumentTextRegion.body,
                  rootBlockOffset: rootBlockOffset,
                  textStyle: bodyStyle,
                ),
              ),
              // Banda del margen inferior: el pie se ancla a
              // `w:pgMar/@footer` desde el borde inferior de la hoja.
              _PageBand(
                minHeightPoints: margins.bottomPoints,
                padding: EdgeInsets.only(
                  bottom: margins.footerDistancePoints,
                  left: margins.leftPoints,
                  right: margins.rightPoints,
                ),
                alignment: Alignment.bottomLeft,
                child: _blockColumn(
                  blocks: footer,
                  region: DocumentTextRegion.footer,
                  rootBlockOffset: 0,
                  textStyle: bodyStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _blockColumn({
    required List<DocumentBlock> blocks,
    required DocumentTextRegion region,
    required int rootBlockOffset,
    required TextStyle textStyle,
  }) {
    if (blocks.isEmpty) {
      return null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++)
          _DocumentBlockWidget(
            region: region,
            rootBlockIndex: rootBlockOffset + blockIndex,
            block: blocks[blockIndex],
            textStyle: textStyle,
            viewerOverlay: viewerOverlay,
          ),
      ],
    );
  }
}

/// Una de las tres franjas horizontales de la hoja (margen superior, área de
/// contenido, margen inferior): nunca mide menos de [minHeightPoints], crece
/// si su contenido no cabe y ancla ese contenido en [alignment].
final class _PageBand extends StatelessWidget {
  const _PageBand({
    required this.minHeightPoints,
    required this.padding,
    required this.alignment,
    required this.child,
  });

  final double minHeightPoints;
  final EdgeInsets padding;
  final Alignment alignment;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = child;
    if (content == null) {
      return SizedBox(height: minHeightPoints);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeightPoints),
      child: Padding(
        padding: padding,
        child: Align(alignment: alignment, child: content),
      ),
    );
  }
}

final class _DocumentBlockWidget extends StatelessWidget {
  const _DocumentBlockWidget({
    required this.rootBlockIndex,
    required this.block,
    required this.textStyle,
    this.region = DocumentTextRegion.body,
    this.viewerOverlay,
    this.prefixSteps = const <DocumentPathStep>[],
  });

  final int rootBlockIndex;
  final DocumentBlock block;
  final TextStyle textStyle;
  final DocumentTextRegion region;
  final DocumentViewerOverlay? viewerOverlay;
  final List<DocumentPathStep> prefixSteps;

  DocumentTextPath _pathForParagraph() {
    return DocumentTextPath(
      region: region,
      steps: <DocumentPathStep>[
        DocumentPathStep.rootBlock(blockIndex: rootBlockIndex),
        ...prefixSteps,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      DocumentParagraphBlock(:final paragraph) => MappingAwareParagraph(
        key: ValueKey<String>(
          '${_pathForParagraph()}-'
          '${paragraph.runs.map((run) => run.text).join()}',
        ),
        path: _pathForParagraph(),
        paragraph: paragraph,
        textStyle: textStyle,
        highlights: const <ParagraphHighlightSegment>[],
        highlightsBuilder: viewerOverlay == null
            ? null
            : () => viewerOverlay!.highlightBuilder(_pathForParagraph()),
        highlightListenable: viewerOverlay?.highlightListenable,
        onSelectionChanged: viewerOverlay?.onSelectionChanged,
      ),
      DocumentTableBlock(:final table) => _DocumentTableWidget(
        rootBlockIndex: rootBlockIndex,
        table: table,
        textStyle: textStyle,
        region: region,
        viewerOverlay: viewerOverlay,
      ),
    };
  }
}

final class _DocumentTableWidget extends StatelessWidget {
  const _DocumentTableWidget({
    required this.rootBlockIndex,
    required this.table,
    required this.textStyle,
    this.region = DocumentTextRegion.body,
    this.viewerOverlay,
  });

  final int rootBlockIndex;
  final DocumentTable table;
  final TextStyle textStyle;
  final DocumentTextRegion region;
  final DocumentViewerOverlay? viewerOverlay;

  @override
  Widget build(BuildContext context) {
    final maxColumns = table.rows.fold<int>(
      0,
      (currentMax, row) => math.max(currentMax, row.cells.length),
    );

    if (maxColumns == 0) {
      return const SizedBox.shrink();
    }

    final grid = <Widget>[
      for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
        for (var cellIndex = 0; cellIndex < maxColumns; cellIndex++)
          if (cellIndex < table.rows[rowIndex].cells.length)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _tableCellPaddingPoints,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (
                    var innerBlockIndex = 0;
                    innerBlockIndex <
                        table.rows[rowIndex].cells[cellIndex].blocks.length;
                    innerBlockIndex++
                  )
                    _DocumentBlockWidget(
                      rootBlockIndex: rootBlockIndex,
                      block: table
                          .rows[rowIndex]
                          .cells[cellIndex]
                          .blocks[innerBlockIndex],
                      textStyle: textStyle,
                      region: region,
                      viewerOverlay: viewerOverlay,
                      prefixSteps: <DocumentPathStep>[
                        DocumentPathStep.cellBlock(
                          rowIndex: rowIndex,
                          cellIndex: cellIndex,
                          blockIndex: innerBlockIndex,
                        ),
                      ],
                    ),
                ],
              ),
            )
          else
            const SizedBox.shrink(),
    ];

    final columnWidths = _columnWidths(maxColumns);
    final rendered = Table(
      // Word solo dibuja retícula cuando el DOCX declara bordes: una tabla
      // sin `w:tblBorders` es invisible salvo por su contenido.
      border: table.borderWidthPoints > 0
          ? TableBorder.all(
              color: _borderColor(),
              width: table.borderWidthPoints,
            )
          : null,
      columnWidths: columnWidths,
      defaultColumnWidth: columnWidths == null
          ? const FlexColumnWidth()
          : const IntrinsicColumnWidth(),
      children: <TableRow>[
        for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
          TableRow(
            children: grid.sublist(
              rowIndex * maxColumns,
              (rowIndex + 1) * maxColumns,
            ),
          ),
      ],
    );

    final totalWidth = _declaredWidthPoints(maxColumns);
    if (totalWidth == null) {
      return rendered;
    }

    // Con la retícula declarada la tabla mide lo que dice el DOCX, y
    // `w:tblPr/w:jc` decide dónde se apoya dentro del área de contenido.
    return Align(
      alignment: switch (table.alignment) {
        DocumentAlignment.center => Alignment.topCenter,
        DocumentAlignment.end => Alignment.topRight,
        DocumentAlignment.start ||
        DocumentAlignment.justify => Alignment.topLeft,
      },
      child: SizedBox(width: totalWidth, child: rendered),
    );
  }

  Map<int, TableColumnWidth>? _columnWidths(int maxColumns) {
    if (table.columnWidthsPoints.length != maxColumns) {
      return null;
    }
    return <int, TableColumnWidth>{
      for (var index = 0; index < maxColumns; index++)
        index: FixedColumnWidth(table.columnWidthsPoints[index]),
    };
  }

  double? _declaredWidthPoints(int maxColumns) {
    if (table.columnWidthsPoints.length != maxColumns) {
      return null;
    }
    final total = table.columnWidthsPoints.fold<double>(
      0,
      (sum, width) => sum + width,
    );
    return total > 0 ? total : null;
  }

  Color _borderColor() {
    final hex = table.borderColorHex;
    final value = hex == null ? null : int.tryParse(hex, radix: 16);
    return value == null ? Colors.black : Color(0xFF000000 | value);
  }
}

/// Dibuja a [scale] lo que su hijo maquetó a tamaño real, y reserva en el
/// layout del padre el espacio ya escalado.
///
/// `Transform.scale` no sirve aquí: escala el pintado pero deja el tamaño sin
/// tocar, así que la hoja seguiría ocupando su tamaño a 1:1 dentro del
/// scroll. Aquí el tamaño propio SÍ es el del hijo por [scale], que es lo que
/// permite maquetar el documento en puntos una sola vez.
final class _ScaledPage extends SingleChildRenderObjectWidget {
  const _ScaledPage({required this.scale, required Widget super.child});

  final double scale;

  @override
  _RenderScaledPage createRenderObject(BuildContext context) =>
      _RenderScaledPage(scale);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderScaledPage renderObject,
  ) {
    renderObject.scale = scale;
  }
}

final class _RenderScaledPage extends RenderProxyBox {
  _RenderScaledPage(this._scale);

  double _scale;

  double get scale => _scale;

  set scale(double value) {
    if (_scale == value) {
      return;
    }
    _scale = value;
    markNeedsLayout();
  }

  Matrix4 get _transform => Matrix4.diagonal3Values(_scale, _scale, 1);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    // El hijo se maqueta sin restricciones: su ancho es el de la hoja en
    // puntos y su alto, el que pida el contenido.
    child.layout(const BoxConstraints(), parentUsesSize: true);
    size = constraints.constrain(child.size * _scale);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) {
      return constraints.smallest;
    }
    return constraints.constrain(
      child.getDryLayout(const BoxConstraints()) * _scale,
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      super.computeMinIntrinsicWidth(height / _scale) * _scale;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      super.computeMaxIntrinsicWidth(height / _scale) * _scale;

  @override
  double computeMinIntrinsicHeight(double width) =>
      super.computeMinIntrinsicHeight(width / _scale) * _scale;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      super.computeMaxIntrinsicHeight(width / _scale) * _scale;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      return;
    }
    if (_scale == 1) {
      context.paintChild(child, offset);
      return;
    }

    _layerHandle.layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (PaintingContext innerContext, Offset innerOffset) =>
          innerContext.paintChild(child, innerOffset),
      oldLayer: _layerHandle.layer,
    );
  }

  final LayerHandle<TransformLayer> _layerHandle =
      LayerHandle<TransformLayer>();

  @override
  void dispose() {
    _layerHandle.layer = null;
    super.dispose();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) {
      return false;
    }

    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          child.hitTest(result, position: transformed),
    );
  }
}

final class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline,
              size: 18,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({
    required this.title,
    this.description,
    this.showProgress = false,
    this.isError = false,
  });

  final String title;
  final String? description;
  final bool showProgress;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = isError ? colorScheme.errorContainer : null;
    final titleColor = isError ? colorScheme.onErrorContainer : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: titleColor),
                ),
                if (description != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: titleColor),
                  ),
                ],
                if (showProgress) ...<Widget>[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
