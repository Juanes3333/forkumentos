import 'package:flutter/material.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/widgets/mapping_aware_paragraph.dart';

typedef ParagraphHighlightBuilder =
    List<ParagraphHighlightSegment> Function(DocumentTextPath path);

final class DocumentViewerOverlay {
  const DocumentViewerOverlay({
    required this.highlightBuilder,
    this.onSelectionChanged,
    this.highlightListenable,
  });

  final ParagraphHighlightBuilder highlightBuilder;

  /// Null disables selection (uses [RichText] so [TextSpan] updates apply).
  /// An empty callback still forces [SelectableText], which can stale spans.
  final void Function(DocumentTextSelection? selection)? onSelectionChanged;

  /// When notified, paragraphs rebuild highlights without rebuilding
  /// the document viewer tree.
  final Listenable? highlightListenable;
}

final class DocumentTextSelection {
  const DocumentTextSelection({
    required this.path,
    required this.startOffset,
    required this.endOffset,
    required this.selectedText,
    this.anchor,
    this.bounds,
  });

  final DocumentTextPath path;
  final int startOffset;
  final int endOffset;
  final String selectedText;
  final Offset? anchor;

  /// Global bounds of the selected text, when available.
  final Rect? bounds;
}
