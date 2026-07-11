import 'package:collection/collection.dart';
import 'package:forkumentos/features/mapping/domain/document_text_catalog.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_validation.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

final class MappingStatistics {
  const MappingStatistics({
    required this.totalFields,
    required this.mappedFieldCount,
    required this.pendingFieldCount,
    required this.totalAssignments,
    required this.missingAssignmentCount,
    required this.duplicateAssignmentCount,
    required this.overlapCount,
    required this.invalidAssignmentCount,
  });

  final int totalFields;
  final int mappedFieldCount;
  final int pendingFieldCount;
  final int totalAssignments;
  final int missingAssignmentCount;
  final int duplicateAssignmentCount;
  final int overlapCount;
  final int invalidAssignmentCount;
}

final class MappingReviewSnapshot {
  const MappingReviewSnapshot({
    required this.statistics,
    required this.validation,
    required this.invalidAssignmentIds,
    required this.isExportReady,
    required this.missingFieldHeaders,
    required this.duplicateAssignments,
    required this.invalidAssignments,
    required this.overlappingAssignmentPairs,
    required this.documentPlaceholders,
  });

  final MappingStatistics statistics;
  final MappingValidationResult validation;
  final List<String> invalidAssignmentIds;
  final bool isExportReady;
  final List<String> missingFieldHeaders;
  final List<FieldAssignment> duplicateAssignments;
  final List<FieldAssignment> invalidAssignments;
  final List<({FieldAssignment first, FieldAssignment second})>
  overlappingAssignmentPairs;
  final List<ParagraphTextEntry> documentPlaceholders;
}

MappingReviewSnapshot buildMappingReviewSnapshot({
  required List<FieldAssignment> assignments,
  required List<String> datasourceHeaders,
  Document? document,
}) {
  final validation = validateMappingAssignments(
    assignments: assignments,
    datasourceHeaders: datasourceHeaders,
  );
  final invalidIds = findInvalidAssignmentIds(
    assignments: assignments,
    datasourceHeaders: datasourceHeaders,
    document: document,
  );
  final invalidAssignments = assignments
      .where((assignment) => invalidIds.contains(assignment.id))
      .toList();
  final duplicateIds = validation.duplicateAssignmentIds.toSet();
  final duplicateAssignments = assignments
      .where((assignment) => duplicateIds.contains(assignment.id))
      .toList();
  final overlappingAssignmentPairs =
      <({FieldAssignment first, FieldAssignment second})>[];
  for (final overlap in validation.overlaps) {
    final first = assignments.firstWhereOrNull(
      (assignment) => assignment.id == overlap.firstId,
    );
    final second = assignments.firstWhereOrNull(
      (assignment) => assignment.id == overlap.secondId,
    );
    if (first != null && second != null) {
      overlappingAssignmentPairs.add((first: first, second: second));
    }
  }

  final assignedFieldIndexes = assignments
      .map((assignment) => assignment.fieldIndex)
      .toSet();
  final mappedFieldCount = assignedFieldIndexes
      .where((index) => index < datasourceHeaders.length)
      .length;

  final statistics = MappingStatistics(
    totalFields: datasourceHeaders.length,
    mappedFieldCount: mappedFieldCount,
    pendingFieldCount: validation.missingFieldIndexes.length,
    totalAssignments: assignments.length,
    missingAssignmentCount: validation.missingFieldIndexes.length,
    duplicateAssignmentCount: duplicateIds.length,
    overlapCount: validation.overlaps.length,
    invalidAssignmentCount: invalidIds.length,
  );

  final documentPlaceholders = document == null
      ? const <ParagraphTextEntry>[]
      : extractDocumentTextPlaceholders(document);

  return MappingReviewSnapshot(
    statistics: statistics,
    validation: validation,
    invalidAssignmentIds: invalidIds,
    isExportReady: isExportReady(
      validation: validation,
      invalidAssignmentIds: invalidIds,
    ),
    missingFieldHeaders: <String>[
      for (final index in validation.missingFieldIndexes)
        if (index < datasourceHeaders.length) datasourceHeaders[index],
    ],
    duplicateAssignments: duplicateAssignments,
    invalidAssignments: invalidAssignments,
    overlappingAssignmentPairs: overlappingAssignmentPairs,
    documentPlaceholders: documentPlaceholders,
  );
}

bool isExportReady({
  required MappingValidationResult validation,
  required List<String> invalidAssignmentIds,
}) {
  // Soft-gate: missing fields are OK (export dialog warns). Hard-block only
  // overlaps, duplicate assignment ids, and invalid assignments.
  return validation.duplicateAssignmentIds.isEmpty &&
      validation.overlaps.isEmpty &&
      invalidAssignmentIds.isEmpty;
}

List<String> findInvalidAssignmentIds({
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

  final invalidIds = <String>[];
  for (final assignment in assignments) {
    if (assignment.fieldIndex >= datasourceHeaders.length) {
      invalidIds.add(assignment.id);
      continue;
    }

    if (!_stillMatchesDocument(assignment, documentTexts)) {
      invalidIds.add(assignment.id);
    }
  }

  return invalidIds;
}

bool _stillMatchesDocument(
  FieldAssignment assignment,
  Map<DocumentTextPath, String>? documentTexts,
) {
  if (documentTexts == null) {
    return true;
  }

  final paragraphText = documentTexts.entries
      .firstWhereOrNull((entry) => _pathsEqual(entry.key, assignment.path))
      ?.value;
  if (paragraphText == null || assignment.endOffset > paragraphText.length) {
    return false;
  }

  return paragraphText.substring(
        assignment.startOffset,
        assignment.endOffset,
      ) ==
      assignment.selectedText;
}

bool _pathsEqual(DocumentTextPath left, DocumentTextPath right) {
  if (left.pageIndex != right.pageIndex ||
      left.steps.length != right.steps.length) {
    return false;
  }

  for (var index = 0; index < left.steps.length; index++) {
    final leftStep = left.steps[index];
    final rightStep = right.steps[index];
    if (leftStep.runtimeType != rightStep.runtimeType) {
      return false;
    }

    if (leftStep is RootDocumentBlockStep &&
        rightStep is RootDocumentBlockStep) {
      if (leftStep.blockIndex != rightStep.blockIndex) {
        return false;
      }
      continue;
    }

    if (leftStep is DocumentTableCellBlockStep &&
        rightStep is DocumentTableCellBlockStep) {
      if (leftStep.rowIndex != rightStep.rowIndex ||
          leftStep.cellIndex != rightStep.cellIndex ||
          leftStep.blockIndex != rightStep.blockIndex) {
        return false;
      }
      continue;
    }

    return false;
  }

  return true;
}
