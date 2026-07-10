import 'package:flutter/material.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/widgets/mapping_aware_paragraph.dart';

typedef ParagraphHighlightBuilder =
    List<ParagraphHighlightSegment> Function(DocumentTextPath path);

final class DocumentViewerOverlay {
  const DocumentViewerOverlay({
    required this.highlightBuilder,
    required this.onSelectionChanged,
  });

  final ParagraphHighlightBuilder highlightBuilder;
  final void Function(DocumentTextSelection? selection) onSelectionChanged;
}

final class DocumentTextSelection {
  const DocumentTextSelection({
    required this.path,
    required this.startOffset,
    required this.endOffset,
    required this.selectedText,
    this.anchor,
  });

  final DocumentTextPath path;
  final int startOffset;
  final int endOffset;
  final String selectedText;
  final Offset? anchor;
}
