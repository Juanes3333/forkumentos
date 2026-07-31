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

final class MappingAwareParagraph extends StatefulWidget {
  const MappingAwareParagraph({
    required this.path,
    required this.paragraph,
    required this.textStyle,
    required this.emptyParagraphHeight,
    required this.highlights,
    this.highlightsBuilder,
    this.highlightListenable,
    this.onSelectionChanged,
    super.key,
  });

  final DocumentTextPath path;
  final DocumentParagraph paragraph;
  final TextStyle textStyle;
  final double emptyParagraphHeight;
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
    final plainText = widget.paragraph.runs.map((run) => run.text).join();
    if (plainText.isEmpty) {
      return SizedBox(height: widget.emptyParagraphHeight);
    }

    final spacingPadding = EdgeInsets.only(
      top: widget.paragraph.spacingBeforePoints,
      bottom: widget.paragraph.spacingAfterPoints,
    );

    if (widget.onSelectionChanged == null) {
      return Padding(
        padding: spacingPadding,
        child: RichText(
          text: TextSpan(
            style: widget.textStyle,
            children: _buildDecoratedSpans(plainText),
          ),
        ),
      );
    }

    return Padding(
      padding: spacingPadding,
      child: SelectableText.rich(
        key: _textKey,
        TextSpan(
          style: widget.textStyle,
          children: _buildDecoratedSpans(plainText),
        ),
        onSelectionChanged: (selection, _) {
          if (!selection.isValid || selection.isCollapsed) {
            widget.onSelectionChanged?.call(null);
            return;
          }

          final selectedText = plainText.substring(
            selection.start,
            selection.end,
          );
          if (selectedText.trim().isEmpty) {
            widget.onSelectionChanged?.call(null);
            return;
          }

          // Uses _textKey's own context (not the outer Padding's) so
          // coordinates stay relative to the text, unaffected by the
          // spacingBeforePoints/spacingAfterPoints padding around it.
          final renderBox =
              _textKey.currentContext?.findRenderObject() as RenderBox?;
          final localBounds = _selectionLocalBounds(
            plainText: plainText,
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

          widget.onSelectionChanged?.call(
            DocumentTextSelection(
              path: widget.path,
              startOffset: selection.start,
              endOffset: selection.end,
              selectedText: selectedText,
              anchor: globalAnchor,
              bounds: globalBounds,
            ),
          );
        },
      ),
    );
  }

  Rect? _selectionLocalBounds({
    required String plainText,
    required TextSelection selection,
    required double maxWidth,
  }) {
    if (maxWidth <= 0) {
      return null;
    }

    final painter = TextPainter(
      text: TextSpan(
        style: widget.textStyle,
        children: _buildDecoratedSpans(plainText),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final boxes = painter.getBoxesForSelection(selection);
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

  List<InlineSpan> _buildDecoratedSpans(String plainText) {
    final highlights = _resolvedHighlights;
    if (highlights.isEmpty) {
      return _runSpans();
    }

    final boundaries = <int>{0, plainText.length};
    for (final highlight in highlights) {
      boundaries
        ..add(highlight.startOffset.clamp(0, plainText.length))
        ..add(highlight.endOffset.clamp(0, plainText.length));
    }

    final sortedBoundaries = boundaries.toList()..sort();
    final spans = <InlineSpan>[];

    for (var index = 0; index < sortedBoundaries.length - 1; index++) {
      final start = sortedBoundaries[index];
      final end = sortedBoundaries[index + 1];
      if (start >= end) {
        continue;
      }

      final segmentText = plainText.substring(start, end);
      final highlight = _highlightCovering(start, end, highlights);
      spans.add(
        TextSpan(
          text: segmentText,
          style: _styleForSegment(start, end, highlight),
        ),
      );
    }

    return spans;
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

  TextStyle _styleForSegment(
    int start,
    int end,
    ParagraphHighlightSegment? highlight,
  ) {
    final runStyle = _runStyleForRange(start, end);
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

  TextStyle _runStyleForRange(int start, int end) {
    var cursor = 0;
    for (final run in widget.paragraph.runs) {
      final runStart = cursor;
      final runEnd = cursor + run.text.length;
      cursor = runEnd;
      if (runEnd <= start || runStart >= end) {
        continue;
      }

      return TextStyle(
        fontWeight: run.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: run.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: run.isUnderlined
            ? TextDecoration.underline
            : TextDecoration.none,
        color: _runColor(run),
        fontSize: _runFontSize(run) ?? widget.textStyle.fontSize,
        height: widget.textStyle.height,
      );
    }

    return widget.textStyle;
  }

  List<InlineSpan> _runSpans() {
    return <InlineSpan>[
      for (final run in widget.paragraph.runs)
        TextSpan(
          text: run.text,
          style: TextStyle(
            fontWeight: run.isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: run.isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: run.isUnderlined
                ? TextDecoration.underline
                : TextDecoration.none,
            color: _runColor(run),
            fontSize: _runFontSize(run),
          ),
        ),
    ];
  }

  Color? _runColor(DocumentRun run) {
    final hex = run.colorHex;
    if (hex == null) {
      return null;
    }
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  // ponytail: duplica el body font size sin zoom de _documentBodyFontSize en
  // document_viewer_screen.dart para escalar el fontSizePoints de un run al
  // mismo nivel de zoom que widget.textStyle, sin enhebrar un parámetro de
  // escala nuevo por todo el árbol de widgets. Si uno cambia, actualizar
  // el otro.
  double? _runFontSize(DocumentRun run) {
    final points = run.fontSizePoints;
    final baseFontSize = widget.textStyle.fontSize;
    if (points == null || baseFontSize == null) {
      return null;
    }
    return points * (baseFontSize / _unzoomedBodyFontSizePoints);
  }
}

const _unzoomedBodyFontSizePoints = 11.0;
