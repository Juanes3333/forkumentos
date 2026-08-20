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
    @Default(false) bool isListField,

    /// Cuántos párrafos consecutivos abarca este campo (incluyendo el
    /// mapeado). null o 1 = campo normal (un solo párrafo, comportamiento
    /// actual). >1 = campo multi-párrafo (reemplaza N párrafos
    /// consecutivos). Cuando el párrafo mapeado tiene numeración, este valor
    /// se IGNORA: el exportador auto-detecta el rango de la lista vía numId.
    int? paragraphSpan,
  }) = _FieldAssignment;
}
