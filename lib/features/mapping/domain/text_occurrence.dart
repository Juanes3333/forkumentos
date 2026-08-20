import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'text_occurrence.freezed.dart';

@freezed
class TextOccurrence with _$TextOccurrence {
  const factory TextOccurrence({
    required DocumentTextPath path,
    required int startOffset,
    required int endOffset,
    required String matchedText,

    /// Ruta del bloque donde termina la coincidencia, si cruza párrafos.
    /// Cuando no es nulo, `endOffset` se interpreta dentro de este bloque en
    /// lugar de dentro de `path` (mismo contrato que
    /// `FieldAssignment.endPath`).
    DocumentTextPath? endPath,
  }) = _TextOccurrence;
}
