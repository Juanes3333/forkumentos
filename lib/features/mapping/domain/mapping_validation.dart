import 'package:forkumentos/features/mapping/domain/document_text_catalog.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

final class MappingValidationResult {
  const MappingValidationResult({
    required this.missingFieldIndexes,
    required this.duplicateAssignmentIds,
    required this.overlaps,
  });

  final List<int> missingFieldIndexes;
  final List<String> duplicateAssignmentIds;
  final List<MappingOverlap> overlaps;

  bool get isValid =>
      missingFieldIndexes.isEmpty &&
      duplicateAssignmentIds.isEmpty &&
      overlaps.isEmpty;
}

final class MappingOverlap {
  const MappingOverlap({required this.firstId, required this.secondId});

  final String firstId;
  final String secondId;
}

MappingValidationResult validateMappingAssignments({
  required List<FieldAssignment> assignments,
  required List<String> datasourceHeaders,
}) {
  return MappingValidationResult(
    missingFieldIndexes: findMissingAssignmentIndexes(
      assignments: assignments,
      datasourceHeaders: datasourceHeaders,
    ),
    duplicateAssignmentIds: findDuplicateAssignmentIds(assignments),
    overlaps: findAssignmentOverlaps(assignments),
  );
}

List<int> findMissingAssignmentIndexes({
  required List<FieldAssignment> assignments,
  required List<String> datasourceHeaders,
}) {
  final assignedIndexes = assignments
      .map((assignment) => assignment.fieldIndex)
      .toSet();

  return <int>[
    for (var index = 0; index < datasourceHeaders.length; index++)
      if (!assignedIndexes.contains(index)) index,
  ];
}

List<String> findDuplicateAssignmentIds(List<FieldAssignment> assignments) {
  final seen = <String>{};
  final duplicates = <String>{};

  for (final assignment in assignments) {
    if (!seen.add(assignment.id)) {
      duplicates.add(assignment.id);
    }
  }

  return duplicates.toList();
}

List<MappingOverlap> findAssignmentOverlaps(List<FieldAssignment> assignments) {
  final overlaps = <MappingOverlap>[];

  for (var leftIndex = 0; leftIndex < assignments.length; leftIndex++) {
    final left = assignments[leftIndex];
    for (
      var rightIndex = leftIndex + 1;
      rightIndex < assignments.length;
      rightIndex++
    ) {
      final right = assignments[rightIndex];
      if (left.path == right.path &&
          left.startOffset < right.endOffset &&
          left.endOffset > right.startOffset) {
        overlaps.add(MappingOverlap(firstId: left.id, secondId: right.id));
      }
    }
  }

  return overlaps;
}

List<FieldAssignment> synchronizeMappingAssignments({
  required List<FieldAssignment> assignments,
  required List<String> datasourceHeaders,
  Document? document,
}) {
  final documentTexts = document == null
      ? null
      : {
          for (final entry in enumerateParagraphTexts(document))
            entry.path: entry.text,
        };

  return assignments
      .where((assignment) => assignment.fieldIndex < datasourceHeaders.length)
      .where(
        (assignment) =>
            assignmentStillMatchesDocument(assignment, documentTexts),
      )
      .map(
        (assignment) => assignment.copyWith(
          fieldHeader: datasourceHeaders[assignment.fieldIndex],
        ),
      )
      .toList();
}

/// Comprueba si [assignment] todavía referencia texto real en
/// [documentTexts] (mapa de `path` -> texto plano del párrafo). `null` en
/// [documentTexts] cuando no hay documento contra el que validar (siempre
/// "sigue coincidiendo").
///
/// Para un rango que cruza párrafos (`endPath != null`), `endOffset` es un
/// offset dentro de `endPath`, NO de `assignment.path` (ver el doc de
/// `FieldAssignment.endPath`): nunca puede usarse como límite de
/// `paragraphText.substring` sobre el párrafo de inicio o lanza `RangeError`
/// cuando `endOffset < startOffset`. Hoy `completeRangeClose` (capa de
/// presentación) no reescribe `selectedText` al cerrar el rango, así que no
/// hay contenido fiable con el que comparar el texto completo del rango;
/// sólo se valida que ambos extremos sigan existiendo y dentro de rango.
bool assignmentStillMatchesDocument(
  FieldAssignment assignment,
  Map<DocumentTextPath, String>? documentTexts,
) {
  if (documentTexts == null) {
    return true;
  }

  final paragraphText = documentTexts[assignment.path];
  if (paragraphText == null ||
      assignment.startOffset < 0 ||
      assignment.startOffset > paragraphText.length) {
    return false;
  }

  final endPath = assignment.endPath;
  if (endPath == null) {
    if (assignment.endOffset < assignment.startOffset ||
        assignment.endOffset > paragraphText.length) {
      return false;
    }
    return paragraphText.substring(
          assignment.startOffset,
          assignment.endOffset,
        ) ==
        assignment.selectedText;
  }

  final endParagraphText = documentTexts[endPath];
  return endParagraphText != null &&
      assignment.endOffset >= 0 &&
      assignment.endOffset <= endParagraphText.length;
}
