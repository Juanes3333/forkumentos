import 'package:flutter/material.dart';
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
    this.onTextSelected,
    super.key,
  });

  final DocumentTextPath path;
  final DocumentParagraph paragraph;
  final TextStyle textStyle;
  final double emptyParagraphHeight;
  final List<ParagraphHighlightSegment> highlights;
  final ValueChanged<DocumentTextSelection>? onTextSelected;

  @override
  State<MappingAwareParagraph> createState() => _MappingAwareParagraphState();
}

final class _MappingAwareParagraphState extends State<MappingAwareParagraph> {
  @override
  Widget build(BuildContext context) {
    final plainText = widget.paragraph.runs.map((run) => run.text).join();
    if (plainText.isEmpty) {
      return SizedBox(height: widget.emptyParagraphHeight);
    }

    if (widget.onTextSelected == null) {
      return RichText(
        text: TextSpan(
          style: widget.textStyle.copyWith(color: Colors.black),
          children: _buildDecoratedSpans(plainText),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(
        style: widget.textStyle.copyWith(color: Colors.black),
        children: _buildDecoratedSpans(plainText),
      ),
      onSelectionChanged: (selection, _) {
        if (!selection.isValid || selection.isCollapsed) {
          return;
        }

        final selectedText = plainText.substring(
          selection.start,
          selection.end,
        );
        if (selectedText.trim().isEmpty) {
          return;
        }

        widget.onTextSelected?.call(
          DocumentTextSelection(
            path: widget.path,
            startOffset: selection.start,
            endOffset: selection.end,
            selectedText: selectedText,
          ),
        );
      },
    );
  }

  List<InlineSpan> _buildDecoratedSpans(String plainText) {
    if (widget.highlights.isEmpty) {
      return _runSpans();
    }

    final boundaries = <int>{0, plainText.length};
    for (final highlight in widget.highlights) {
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
      final highlight = _highlightCovering(start, end);
      spans.add(
        TextSpan(
          text: segmentText,
          style: _styleForSegment(start, end, highlight),
        ),
      );
    }

    return spans;
  }

  ParagraphHighlightSegment? _highlightCovering(int start, int end) {
    for (final highlight in widget.highlights) {
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

    final alpha = highlight.emphasize ? 0.45 : 0.28;
    return runStyle.copyWith(
      backgroundColor: highlight.color.withValues(alpha: alpha),
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
        fontSize: widget.textStyle.fontSize,
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
          ),
        ),
    ];
  }
}
