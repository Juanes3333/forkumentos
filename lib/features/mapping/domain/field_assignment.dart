import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'field_assignment.freezed.dart';

@freezed
class FieldAssignment with _$FieldAssignment {
  const factory FieldAssignment({
    required String id,
    required int fieldIndex,
    required String fieldHeader,
    required String selectedText,
    required DocumentTextPath path,
    required int startOffset,
    required int endOffset,
  }) = _FieldAssignment;
}
