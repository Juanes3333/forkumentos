import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

List<Map<String, dynamic>> mappingAssignmentsToJson(
  List<FieldAssignment> assignments,
) {
  return assignments.map(fieldAssignmentToJson).toList();
}

List<FieldAssignment> mappingAssignmentsFromJson(List<Object?> rawAssignments) {
  return rawAssignments
      .whereType<Map<Object?, Object?>>()
      .map((raw) => fieldAssignmentFromJson(raw.cast<String, dynamic>()))
      .toList();
}

Map<String, dynamic> fieldAssignmentToJson(FieldAssignment assignment) {
  return <String, dynamic>{
    'id': assignment.id,
    'fieldIndex': assignment.fieldIndex,
    'fieldHeader': assignment.fieldHeader,
    'selectedText': assignment.selectedText,
    'path': documentTextPathToJson(assignment.path),
    'startOffset': assignment.startOffset,
    'endOffset': assignment.endOffset,
  };
}

FieldAssignment fieldAssignmentFromJson(Map<String, dynamic> json) {
  return FieldAssignment(
    id: json['id'] as String,
    fieldIndex: json['fieldIndex'] as int,
    fieldHeader: json['fieldHeader'] as String,
    selectedText: json['selectedText'] as String,
    path: documentTextPathFromJson(json['path'] as Map<String, dynamic>),
    startOffset: json['startOffset'] as int,
    endOffset: json['endOffset'] as int,
  );
}

Map<String, dynamic> documentTextPathToJson(DocumentTextPath path) {
  return <String, dynamic>{
    'pageIndex': path.pageIndex,
    'steps': path.steps.map(documentPathStepToJson).toList(),
  };
}

DocumentTextPath documentTextPathFromJson(Map<String, dynamic> json) {
  return DocumentTextPath(
    pageIndex: json['pageIndex'] as int,
    steps: (json['steps'] as List<Object?>)
        .whereType<Map<Object?, Object?>>()
        .map((raw) => documentPathStepFromJson(raw.cast<String, dynamic>()))
        .toList(),
  );
}

Map<String, dynamic> documentPathStepToJson(DocumentPathStep step) {
  return switch (step) {
    RootDocumentBlockStep(:final blockIndex) => <String, dynamic>{
      'type': 'rootBlock',
      'blockIndex': blockIndex,
    },
    DocumentTableCellBlockStep(
      :final rowIndex,
      :final cellIndex,
      :final blockIndex,
    ) =>
      <String, dynamic>{
        'type': 'cellBlock',
        'rowIndex': rowIndex,
        'cellIndex': cellIndex,
        'blockIndex': blockIndex,
      },
  };
}

DocumentPathStep documentPathStepFromJson(Map<String, dynamic> json) {
  return switch (json['type'] as String) {
    'rootBlock' => DocumentPathStep.rootBlock(
      blockIndex: json['blockIndex'] as int,
    ),
    'cellBlock' => DocumentPathStep.cellBlock(
      rowIndex: json['rowIndex'] as int,
      cellIndex: json['cellIndex'] as int,
      blockIndex: json['blockIndex'] as int,
    ),
    final type => throw FormatException('Unknown document path step: $type'),
  };
}
