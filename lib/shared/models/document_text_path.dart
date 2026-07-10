import 'package:freezed_annotation/freezed_annotation.dart';

part 'document_text_path.freezed.dart';

@freezed
class DocumentTextPath with _$DocumentTextPath {
  const factory DocumentTextPath({
    required int pageIndex,
    required List<DocumentPathStep> steps,
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
