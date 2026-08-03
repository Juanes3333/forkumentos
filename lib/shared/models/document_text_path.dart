import 'package:freezed_annotation/freezed_annotation.dart';

part 'document_text_path.freezed.dart';

/// Where a [DocumentTextPath] points: the repeating body pages, or the
/// document-wide header/footer (which has no real page of its own).
enum DocumentTextRegion { body, header, footer }

/// Identifies a paragraph by structure alone, never by which page it visually
/// lands on. `steps` has no `pageIndex`: a page boundary in `Document.pages`
/// comes from ingestion's page-fill heuristic (see `docx_document_repository
/// .dart`'s `_extractPages`), which the exporter never reproduces — keying by
/// page number made mapped fields silently miss their replacement whenever a
/// template had no `w:lastRenderedPageBreak` markers to pin the heuristic
/// down. `RootDocumentBlockStep.blockIndex` is the absolute, page-agnostic
/// position of the top-level block in document order, which both ingestion
/// (`document_text_catalog.dart`) and export (`docx_zip_exporter.dart`)
/// compute identically by simply counting `<w:p>`/`<w:tbl>` in document
/// order — no pagination of any kind involved, so the two can never drift.
@freezed
class DocumentTextPath with _$DocumentTextPath {
  const factory DocumentTextPath({
    required List<DocumentPathStep> steps,
    @Default(DocumentTextRegion.body) DocumentTextRegion region,
  }) = _DocumentTextPath;
}

@freezed
sealed class DocumentPathStep with _$DocumentPathStep {
  /// [blockIndex] is the absolute, page-agnostic index of this block in
  /// document order (see the [DocumentTextPath] doc comment) — not an index
  /// into any single `DocumentPage.blocks` list.
  const factory DocumentPathStep.rootBlock({required int blockIndex}) =
      RootDocumentBlockStep;

  const factory DocumentPathStep.cellBlock({
    required int rowIndex,
    required int cellIndex,
    required int blockIndex,
  }) = DocumentTableCellBlockStep;
}
