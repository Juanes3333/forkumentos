import 'dart:math' as math;

import 'package:flutter/material.dart';
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

                return ColoredBox(
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
                              children: <Widget>[
                                for (
                                  var index = 0;
                                  index < document.pages.length;
                                  index++
                                ) ...<Widget>[
                                  Align(
                                    key: _pageKeys[index],
                                    alignment: Alignment.topCenter,
                                    child: _DocumentPageSheet(
                                      pageIndex: index,
                                      page: document.pages[index],
                                      scale: effectiveScale,
                                      viewerOverlay: widget.viewerOverlay,
                                    ),
                                  ),
                                  if (index < document.pages.length - 1)
                                    const SizedBox(height: _pageSpacing),
                                ],
                              ],
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

    await Scrollable.ensureVisible(
      pageContext,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
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

final class _DocumentPageSheet extends StatelessWidget {
  const _DocumentPageSheet({
    required this.pageIndex,
    required this.page,
    required this.scale,
    this.viewerOverlay,
  });

  final int pageIndex;
  final DocumentPage page;
  final double scale;
  final DocumentViewerOverlay? viewerOverlay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodyStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final scaledBodyStyle = bodyStyle.copyWith(
      fontSize: (bodyStyle.fontSize ?? 14) * scale,
    );
    final scaledLineHeight =
        (scaledBodyStyle.fontSize ?? 14) * (scaledBodyStyle.height ?? 1.3);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        // Solo se fija el ancho de la hoja; el alto es un mínimo, no un
        // máximo. Como la paginación no reproduce el reflow real de Word
        // (ver nota en docx_document_repository.dart), una página sin
        // marcadores explícitos puede contener más contenido del que cabe
        // en el alto nominal: se permite crecer en vez de recortar.
        constraints: BoxConstraints(
          minWidth: page.widthPoints * scale,
          maxWidth: page.widthPoints * scale,
          minHeight: page.heightPoints * scale,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: page.margins.topPoints * scale,
            right: page.margins.rightPoints * scale,
            bottom: page.margins.bottomPoints * scale,
            left: page.margins.leftPoints * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (
                var blockIndex = 0;
                blockIndex < page.blocks.length;
                blockIndex++
              )
                _DocumentBlockWidget(
                  pageIndex: pageIndex,
                  rootBlockIndex: blockIndex,
                  block: page.blocks[blockIndex],
                  textStyle: scaledBodyStyle,
                  emptyParagraphHeight: scaledLineHeight,
                  viewerOverlay: viewerOverlay,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _DocumentBlockWidget extends StatelessWidget {
  const _DocumentBlockWidget({
    required this.pageIndex,
    required this.rootBlockIndex,
    required this.block,
    required this.textStyle,
    required this.emptyParagraphHeight,
    this.viewerOverlay,
    this.prefixSteps = const <DocumentPathStep>[],
  });

  final int pageIndex;
  final int rootBlockIndex;
  final DocumentBlock block;
  final TextStyle textStyle;
  final double emptyParagraphHeight;
  final DocumentViewerOverlay? viewerOverlay;
  final List<DocumentPathStep> prefixSteps;

  DocumentTextPath _pathForParagraph() {
    return DocumentTextPath(
      pageIndex: pageIndex,
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
        emptyParagraphHeight: emptyParagraphHeight,
        highlights: const <ParagraphHighlightSegment>[],
        highlightsBuilder: viewerOverlay == null
            ? null
            : () => viewerOverlay!.highlightBuilder(_pathForParagraph()),
        highlightListenable: viewerOverlay?.highlightListenable,
        onSelectionChanged: viewerOverlay?.onSelectionChanged,
      ),
      DocumentTableBlock(:final table) => Padding(
        padding: EdgeInsets.only(bottom: emptyParagraphHeight * 0.25),
        child: _DocumentTableWidget(
          pageIndex: pageIndex,
          rootBlockIndex: rootBlockIndex,
          table: table,
          textStyle: textStyle,
          emptyParagraphHeight: emptyParagraphHeight,
          viewerOverlay: viewerOverlay,
        ),
      ),
    };
  }
}

final class _DocumentTableWidget extends StatelessWidget {
  const _DocumentTableWidget({
    required this.pageIndex,
    required this.rootBlockIndex,
    required this.table,
    required this.textStyle,
    required this.emptyParagraphHeight,
    this.viewerOverlay,
  });

  final int pageIndex;
  final int rootBlockIndex;
  final DocumentTable table;
  final TextStyle textStyle;
  final double emptyParagraphHeight;
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

    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    return Table(
      border: TableBorder.all(color: borderColor, width: 0.6),
      children: <TableRow>[
        for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
          TableRow(
            children: <Widget>[
              for (var cellIndex = 0; cellIndex < maxColumns; cellIndex++)
                if (cellIndex < table.rows[rowIndex].cells.length)
                  Padding(
                    padding: EdgeInsets.all(emptyParagraphHeight * 0.25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (
                          var innerBlockIndex = 0;
                          innerBlockIndex <
                              table
                                  .rows[rowIndex]
                                  .cells[cellIndex]
                                  .blocks
                                  .length;
                          innerBlockIndex++
                        )
                          _DocumentBlockWidget(
                            pageIndex: pageIndex,
                            rootBlockIndex: rootBlockIndex,
                            block: table
                                .rows[rowIndex]
                                .cells[cellIndex]
                                .blocks[innerBlockIndex],
                            textStyle: textStyle,
                            emptyParagraphHeight: emptyParagraphHeight,
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
            ],
          ),
      ],
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
