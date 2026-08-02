import 'package:flutter/material.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';

final class ParagraphHighlightSegment {
  const ParagraphHighlightSegment({
    required this.startOffset,
    required this.endOffset,
    required this.color,
    this.isSuggestion = false,
    this.emphasize = false,
  });

  final int startOffset;
  final int endOffset;
  final Color color;
  final bool isSuggestion;
  final bool emphasize;
}

/// Un párrafo del documento dibujado con la tipografía que declara el DOCX:
/// fuente, tamaño, alineación, sangrías, interlineado y las imágenes
/// incrustadas en el punto exacto del flujo de texto que ocupan.
///
/// Todas las medidas son PUNTOS de documento, no píxeles lógicos: el zoom lo
/// aplica el visor al pintar la hoja completa, de modo que los saltos de
/// línea son los mismos a cualquier nivel de zoom, igual que en Word.
final class MappingAwareParagraph extends StatefulWidget {
  const MappingAwareParagraph({
    required this.path,
    required this.paragraph,
    required this.textStyle,
    required this.highlights,
    this.highlightsBuilder,
    this.highlightListenable,
    this.onSelectionChanged,
    super.key,
  });

  final DocumentTextPath path;
  final DocumentParagraph paragraph;
  final TextStyle textStyle;
  final List<ParagraphHighlightSegment> highlights;

  /// When set, called on every build (including listenable ticks).
  final List<ParagraphHighlightSegment> Function()? highlightsBuilder;
  final Listenable? highlightListenable;
  final ValueChanged<DocumentTextSelection?>? onSelectionChanged;

  @override
  State<MappingAwareParagraph> createState() => _MappingAwareParagraphState();
}

final class _MappingAwareParagraphState extends State<MappingAwareParagraph> {
  // Attached to the text widget itself (not the outer Padding) so that
  // findRenderObject() below keeps returning the text's own render box even
  // after wrapping it for spacingBeforePoints/spacingAfterPoints.
  final _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.highlightListenable?.addListener(_onHighlightTick);
  }

  @override
  void didUpdateWidget(covariant MappingAwareParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightListenable != widget.highlightListenable) {
      oldWidget.highlightListenable?.removeListener(_onHighlightTick);
      widget.highlightListenable?.addListener(_onHighlightTick);
    }
  }

  @override
  void dispose() {
    widget.highlightListenable?.removeListener(_onHighlightTick);
    super.dispose();
  }

  void _onHighlightTick() {
    if (mounted) {
      setState(() {});
    }
  }

  List<ParagraphHighlightSegment> get _resolvedHighlights =>
      widget.highlightsBuilder?.call() ?? widget.highlights;

  @override
  Widget build(BuildContext context) {
    final paragraph = widget.paragraph;
    final content = _buildContent();

    // El espaciado y las sangrías de Word son márgenes del párrafo: se
    // aplican también a los párrafos vacíos, que en un documento real son la
    // forma habitual de separar bloques.
    final padding = EdgeInsets.only(
      top: paragraph.spacingBeforePoints,
      bottom: paragraph.spacingAfterPoints,
      left: paragraph.indentLeftPoints,
      right: paragraph.indentRightPoints,
    );

    if (content.isEmpty) {
      return Padding(
        padding: padding,
        child: SizedBox(height: _emptyParagraphHeight()),
      );
    }

    final rootStyle = _paragraphStyle();
    if (widget.onSelectionChanged == null) {
      return Padding(
        padding: padding,
        child: RichText(
          key: _textKey,
          textAlign: _textAlign(),
          text: TextSpan(style: rootStyle, children: content.spans),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: SelectableText.rich(
        key: _textKey,
        textAlign: _textAlign(),
        TextSpan(style: rootStyle, children: content.spans),
        onSelectionChanged: (selection, _) =>
            _handleSelectionChanged(selection, content),
      ),
    );
  }

  void _handleSelectionChanged(
    TextSelection selection,
    _ParagraphContent content,
  ) {
    final onSelectionChanged = widget.onSelectionChanged;
    if (onSelectionChanged == null) {
      return;
    }
    if (!selection.isValid || selection.isCollapsed) {
      onSelectionChanged(null);
      return;
    }

    // La selección viene en el espacio del pintor, que cuenta un carácter
    // por cada WidgetSpan (imágenes y sangría de primera línea). Los offsets
    // de mapeo son del texto del documento, sin esos placeholders.
    final plainText = _plainText();
    final startOffset = content
        .toDocumentOffset(selection.start)
        .clamp(0, plainText.length);
    final endOffset = content
        .toDocumentOffset(selection.end)
        .clamp(0, plainText.length);
    if (startOffset >= endOffset) {
      onSelectionChanged(null);
      return;
    }

    final selectedText = plainText.substring(startOffset, endOffset);
    if (selectedText.trim().isEmpty) {
      onSelectionChanged(null);
      return;
    }

    // Uses _textKey's own context (not the outer Padding's) so coordinates
    // stay relative to the text, unaffected by the spacing/indent padding
    // around it.
    final renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    final localBounds = _selectionLocalBounds(
      content: content,
      selection: selection,
      maxWidth: renderBox?.size.width ?? 0,
    );
    final globalBounds = renderBox == null || localBounds == null
        ? null
        : Rect.fromPoints(
            renderBox.localToGlobal(localBounds.topLeft),
            renderBox.localToGlobal(localBounds.bottomRight),
          );
    // Bottom-left of the selection so the tooltip clears the text and
    // left-aligns with the selection start.
    final globalAnchor =
        globalBounds?.bottomLeft ??
        (renderBox == null
            ? const Offset(120, 80)
            : renderBox.localToGlobal(Offset(0, renderBox.size.height)));

    onSelectionChanged(
      DocumentTextSelection(
        path: widget.path,
        startOffset: startOffset,
        endOffset: endOffset,
        selectedText: selectedText,
        anchor: globalAnchor,
        bounds: globalBounds,
      ),
    );
  }

  Rect? _selectionLocalBounds({
    required _ParagraphContent content,
    required TextSelection selection,
    required double maxWidth,
  }) {
    if (maxWidth <= 0) {
      return null;
    }

    final painter = TextPainter(
      text: TextSpan(style: _paragraphStyle(), children: content.spans),
      textAlign: _textAlign(),
      textDirection: TextDirection.ltr,
    );
    // Los WidgetSpan necesitan una medida explícita: sin ella el pintor
    // lanza al maquetar un párrafo con imágenes.
    if (content.placeholderSizes.isNotEmpty) {
      painter.setPlaceholderDimensions(<PlaceholderDimensions>[
        for (final size in content.placeholderSizes)
          PlaceholderDimensions(
            size: size,
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            baselineOffset: size.height,
          ),
      ]);
    }
    painter.layout(maxWidth: maxWidth);

    final boxes = painter.getBoxesForSelection(selection);
    painter.dispose();
    if (boxes.isEmpty) {
      return null;
    }

    return boxes
        .skip(1)
        .fold<Rect>(
          boxes.first.toRect(),
          (Rect acc, TextBox box) => acc.expandToInclude(box.toRect()),
        );
  }

  String _plainText() => widget.paragraph.runs.map((run) => run.text).join();

  TextAlign _textAlign() {
    return switch (widget.paragraph.alignment) {
      DocumentAlignment.start => TextAlign.left,
      DocumentAlignment.center => TextAlign.center,
      DocumentAlignment.end => TextAlign.right,
      DocumentAlignment.justify => TextAlign.justify,
    };
  }

  TextStyle _paragraphStyle() {
    final fontSize =
        (widget.textStyle.fontSize ?? _fallbackFontSizePoints) * _visualScale;
    // El tamaño va explícito además del alto: `_lineHeightFactor` devuelve un
    // factor calculado sobre ESTE tamaño, y `TextStyle.height` multiplica el
    // tamaño que acabe teniendo el estilo. Dejar heredar el nominal mientras
    // el factor asume el escalado descuadraría el interlineado exacto.
    return widget.textStyle.copyWith(
      fontSize: fontSize,
      height: _lineHeightFactor(fontSize, widget.textStyle.fontFamily),
    );
  }

  double _emptyParagraphHeight() {
    final firstRun = widget.paragraph.runs.isEmpty
        ? null
        : widget.paragraph.runs.first;
    final fontSize =
        (firstRun?.fontSizePoints ??
            widget.textStyle.fontSize ??
            _fallbackFontSizePoints) *
        _visualScale;
    final fontFamily = firstRun?.fontFamily ?? widget.textStyle.fontFamily;
    return fontSize *
        (_lineHeightFactor(fontSize, fontFamily) ??
            naturalLineHeightRatio(fontFamily));
  }

  /// Multiplicador de `TextStyle.height` equivalente al interlineado del
  /// DOCX. `null` = interlineado natural de la fuente (el sencillo de Word).
  ///
  /// [fontSizePoints] debe ser SIEMPRE el tamaño ya escalado por
  /// [_visualScale], el mismo que acabe en `TextStyle.fontSize`: Flutter
  /// resuelve el alto de línea como `height * fontSize`, así que mezclar el
  /// tamaño nominal aquí con el escalado allí desplazaría el interlineado.
  double? _lineHeightFactor(double fontSizePoints, String? fontFamily) {
    // `w:line` con `w:lineRule="exact"` es una restricción tipográfica dura
    // que el documento fija en puntos absolutos, no una medida derivada del
    // tamaño de fuente: Word la respeta al pie de la letra. Dividir por el
    // tamaño YA escalado hace que `height * fontSize` vuelva a dar
    // exactamente `exactPoints`, de modo que el escalado visual encoge la
    // letra pero deja intacto el interlineado que el DOCX declaró. Además un
    // párrafo de interlineado exacto no puede desbordar: su alto es idéntico
    // en Word y en Flutter, así que no necesita compensación alguna.
    final exactPoints = widget.paragraph.lineSpacingExactPoints;
    if (exactPoints != null && fontSizePoints > 0) {
      return exactPoints / fontSizePoints;
    }

    final multiple = widget.paragraph.lineSpacingMultiple;
    if (multiple == null || multiple == 1) {
      return null;
    }
    // Word multiplica el alto NATURAL de la línea, no el tamaño de fuente;
    // `TextStyle.height` multiplica el tamaño de fuente. La proporción real
    // de la fuente cierra la diferencia.
    return multiple * naturalLineHeightRatio(fontFamily);
  }

  _ParagraphContent _buildContent() {
    final highlights = _resolvedHighlights;
    final spans = <InlineSpan>[];
    final placeholderOffsets = <int>[];
    final placeholderSizes = <Size>[];
    var painterOffset = 0;
    var documentOffset = 0;

    void addPlaceholder(Widget child, Size size) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: child,
        ),
      );
      placeholderOffsets.add(painterOffset);
      placeholderSizes.add(size);
      painterOffset += 1;
    }

    // Sangría de primera línea: Flutter no la expresa en el TextStyle, pero
    // un hueco vacío al inicio del flujo tiene el mismo efecto. La sangría
    // francesa (valor negativo) no es representable así; queda absorbida por
    // indentLeftPoints, que ya alinea el cuerpo del párrafo donde Word lo
    // pone.
    final firstLineIndent = widget.paragraph.indentFirstLinePoints;
    if (firstLineIndent > 0) {
      addPlaceholder(
        SizedBox(width: firstLineIndent),
        Size(firstLineIndent, 0),
      );
    }

    for (final run in widget.paragraph.runs) {
      final image = run.image;
      if (image != null) {
        addPlaceholder(
          Image.memory(
            image.bytes,
            width: image.widthPoints,
            height: image.heightPoints,
            // Word dibuja la imagen exactamente al tamaño declarado en el
            // DOCX, sin respetar la relación de aspecto del archivo.
            fit: BoxFit.fill,
          ),
          Size(image.widthPoints, image.heightPoints),
        );
        continue;
      }

      if (run.text.isEmpty) {
        continue;
      }

      final runStyle = _runStyle(run);
      for (final piece in _splitRun(run.text, documentOffset, highlights)) {
        spans.add(
          TextSpan(
            text: piece.text,
            style: _applyHighlight(runStyle, piece.highlight),
          ),
        );
        painterOffset += piece.text.length;
      }
      documentOffset += run.text.length;
    }

    return _ParagraphContent(
      spans: spans,
      placeholderOffsets: placeholderOffsets,
      placeholderSizes: placeholderSizes,
    );
  }

  Iterable<_TextPiece> _splitRun(
    String text,
    int documentStart,
    List<ParagraphHighlightSegment> highlights,
  ) sync* {
    if (highlights.isEmpty) {
      yield _TextPiece(text: text);
      return;
    }

    final documentEnd = documentStart + text.length;
    final boundaries = <int>{documentStart, documentEnd};
    for (final highlight in highlights) {
      for (final offset in <int>[highlight.startOffset, highlight.endOffset]) {
        if (offset > documentStart && offset < documentEnd) {
          boundaries.add(offset);
        }
      }
    }

    final sorted = boundaries.toList()..sort();
    for (var index = 0; index < sorted.length - 1; index++) {
      final start = sorted[index];
      final end = sorted[index + 1];
      if (start >= end) {
        continue;
      }
      yield _TextPiece(
        text: text.substring(start - documentStart, end - documentStart),
        highlight: _highlightCovering(start, end, highlights),
      );
    }
  }

  ParagraphHighlightSegment? _highlightCovering(
    int start,
    int end,
    List<ParagraphHighlightSegment> highlights,
  ) {
    for (final highlight in highlights) {
      if (start >= highlight.startOffset && end <= highlight.endOffset) {
        return highlight;
      }
    }
    return null;
  }

  TextStyle _applyHighlight(
    TextStyle runStyle,
    ParagraphHighlightSegment? highlight,
  ) {
    if (highlight == null) {
      return runStyle;
    }

    if (highlight.emphasize) {
      final accent = AppColors.of(context).accent;
      return runStyle.copyWith(
        backgroundColor: accent.withValues(alpha: 0.55),
        decoration: TextDecoration.underline,
        decorationColor: accent,
        decorationThickness: 2.4,
      );
    }

    return runStyle.copyWith(
      backgroundColor: highlight.color.withValues(alpha: 0.28),
      decoration: highlight.isSuggestion
          ? TextDecoration.underline
          : TextDecoration.combine(<TextDecoration>[
              if (runStyle.decoration != null) runStyle.decoration!,
              TextDecoration.underline,
            ]),
      decorationColor: highlight.color,
      decorationThickness: highlight.isSuggestion ? 1.2 : 2,
    );
  }

  TextStyle _runStyle(DocumentRun run) {
    // `null` conserva su significado original: hereda el tamaño del estilo
    // ambiente. Sólo se escala el tamaño que este widget sí resuelve.
    final nominalFontSize = run.fontSizePoints ?? widget.textStyle.fontSize;
    final fontSize = nominalFontSize == null
        ? null
        : nominalFontSize * _visualScale;
    final fontFamily = run.fontFamily ?? widget.textStyle.fontFamily;
    return widget.textStyle.copyWith(
      fontWeight: run.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: run.isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: run.isUnderlined
          ? TextDecoration.underline
          : TextDecoration.none,
      color: _runColor(run) ?? widget.textStyle.color,
      fontSize: fontSize,
      fontFamily: fontFamily,
      height: _lineHeightFactor(
        fontSize ?? _fallbackFontSizePoints * _visualScale,
        fontFamily,
      ),
    );
  }

  Color? _runColor(DocumentRun run) {
    final hex = run.colorHex;
    if (hex == null) {
      return null;
    }
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}

/// Los spans ya construidos de un párrafo más lo necesario para traducir
/// entre el espacio del pintor (donde cada WidgetSpan ocupa un carácter) y
/// los offsets del texto del documento que usa el mapeo.
final class _ParagraphContent {
  const _ParagraphContent({
    required this.spans,
    required this.placeholderOffsets,
    required this.placeholderSizes,
  });

  final List<InlineSpan> spans;
  final List<int> placeholderOffsets;
  final List<Size> placeholderSizes;

  bool get isEmpty => spans.isEmpty;

  int toDocumentOffset(int painterOffset) {
    var placeholdersBefore = 0;
    for (final offset in placeholderOffsets) {
      if (offset < painterOffset) {
        placeholdersBefore++;
      }
    }
    return painterOffset - placeholdersBefore;
  }
}

final class _TextPiece {
  const _TextPiece({required this.text, this.highlight});

  final String text;
  final ParagraphHighlightSegment? highlight;
}

const _fallbackFontSizePoints = 11.0;

/// Sólo visual: compensa que Flutter maqueta el texto ligeramente más alto que
/// Word al mismo tamaño nominal, para que una página que el parser dio por
/// completa no desborde el alto de la hoja. NO toca el modelo de datos —
/// `DocumentRun.fontSizePoints` sigue intacto y la exportación a DOCX y PDF
/// lee el modelo, así que sale al 100% del tamaño real.
///
/// De dónde sale el número: el paginador de `docx_document_repository.dart`
/// presupuesta cada línea como `fontSize * 1.17`, el promedio medido de las
/// fuentes de cuerpo de Windows. Este widget, en cambio, mide la fuente real
/// instalada con `naturalLineHeightRatio`, y la peor de esas fuentes es
/// justo la de cuerpo por defecto de Word: Calibri, 2500/2048 = 1,2207
/// (GDI+ `GetLineSpacing/GetEmHeight`). Una página llena rinde entonces
/// 1,2207 / 1,17 = 4,3% más alta que el presupuesto con el que se cortó, y
/// desborda. El techo seguro es 1,17 / 1,2207 = 0,9585; 0,95 es el mayor
/// valor de dos decimales por debajo de ese techo, con ~1% de holgura para
/// que Skia pueda reportar métricas algo mayores que GDI+.
///
/// Cambiar este valor rompe a propósito la prueba de calibración de
/// `test/widget/shared/widgets/mapping_aware_paragraph_test.dart`.
const _visualScale = 0.95;

final Map<String, double> _naturalLineHeightRatios = <String, double>{};

/// Alto natural de línea de [fontFamily] como fracción del tamaño de fuente,
/// medido con la fuente real instalada. Word expresa el interlineado
/// "múltiple" sobre este alto, así que sin él un 1.15 de Word no coincide con
/// un `height: 1.15` de Flutter.
double naturalLineHeightRatio(String? fontFamily) {
  final key = fontFamily ?? '';
  final cached = _naturalLineHeightRatios[key];
  if (cached != null) {
    return cached;
  }

  final painter = TextPainter(
    text: TextSpan(
      text: 'Hg',
      style: TextStyle(fontFamily: fontFamily, fontSize: 100),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final ratio = painter.preferredLineHeight / 100;
  painter.dispose();

  _naturalLineHeightRatios[key] = ratio;
  return ratio;
}
