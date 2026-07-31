import 'package:freezed_annotation/freezed_annotation.dart';

part 'document_text_path.freezed.dart';

/// Where a [DocumentTextPath] points: the repeating body pages, or the
/// document-wide header/footer (which has no real page of its own).
enum DocumentTextRegion { body, header, footer }

@freezed
class DocumentTextPath with _$DocumentTextPath {
  const factory DocumentTextPath({
    required int pageIndex,
    required List<DocumentPathStep> steps,
    @Default(DocumentTextRegion.body) DocumentTextRegion region,
  }) = _DocumentTextPath;
}

@freezed
sealed class DocumentPathStep with _$DocumentPathStep {
  const factory DocumentPathStep.rootBlock({required int blockIndex}) =
      RootDocumentBlockStep;

  const factory DocumentPathStep.cellBlock({
    required int rowIndex,
    required int cellIndex,
    required int blockIndex,
  }) = DocumentTableCellBlockStep;
}
