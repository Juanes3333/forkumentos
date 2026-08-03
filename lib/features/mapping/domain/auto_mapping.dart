import 'dart:math' as math;

import 'package:forkumentos/features/mapping/domain/document_text_catalog.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/shared/models/document.dart';

final class AutoMappingResult {
  const AutoMappingResult({
    required this.assignments,
    required this.skippedCount,
    required this.occurrenceCountsByField,
  });

  /// Solo las asignaciones NUEVAS; quien llama las agrega a las existentes.
  final List<FieldAssignment> assignments;

  /// Ocurrencias descartadas porque ese tramo ya estaba asignado.
  final int skippedCount;

  /// fieldIndex -> cuántas asignaciones se crearon para esa columna.
  ///
  /// Solo aparecen las columnas que produjeron al menos una. Cuenta lo que
  /// realmente se creó (ya descontados los solapamientos), que es a lo que el
  /// usuario se compromete si confirma.
  final Map<int, int> occurrenceCountsByField;
}

/// Busca en el documento el valor de cada columna de [firstRow] y ancla una
/// asignación en cada ocurrencia exacta que no pise un tramo ya tomado.
///
/// Recorre las columnas en orden de cabecera, así que ante un mismo valor en
/// dos columnas gana la primera. Los tramos reclamados durante esta misma
/// pasada cuentan como ocupados, igual que [existingAssignments].
AutoMappingResult buildAutoMapping({
  required Document document,
  required List<String> headers,
  required List<String?> firstRow,
  required List<FieldAssignment> existingAssignments,
  required String Function() generateId,
}) {
  final claimed = <FieldAssignment>[...existingAssignments];
  final created = <FieldAssignment>[];
  var skippedCount = 0;

  final columnCount = math.min(headers.length, firstRow.length);
  for (var fieldIndex = 0; fieldIndex < columnCount; fieldIndex++) {
    final value = firstRow[fieldIndex]?.trim() ?? '';
    if (value.isEmpty) {
      continue;
    }

    final occurrences = findExactTextOccurrences(
      document: document,
      needle: value,
    );
    for (final occurrence in occurrences) {
      final conflict = findOverlappingAssignment(
        assignments: claimed,
        path: occurrence.path,
        startOffset: occurrence.startOffset,
        endOffset: occurrence.endOffset,
      );
      if (conflict != null) {
        skippedCount++;
        continue;
      }

      final assignment = FieldAssignment(
        id: generateId(),
        fieldIndex: fieldIndex,
        fieldHeader: headers[fieldIndex],
        selectedText: occurrence.matchedText,
        path: occurrence.path,
        startOffset: occurrence.startOffset,
        endOffset: occurrence.endOffset,
      );
      claimed.add(assignment);
      created.add(assignment);
    }
  }

  final occurrenceCountsByField = <int, int>{};
  for (final assignment in created) {
    occurrenceCountsByField.update(
      assignment.fieldIndex,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  return AutoMappingResult(
    assignments: created,
    skippedCount: skippedCount,
    occurrenceCountsByField: occurrenceCountsByField,
  );
}
