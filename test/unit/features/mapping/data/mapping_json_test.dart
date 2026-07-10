import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/data/mapping_json.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  test('serializa y restaura asignaciones de mapping', () {
    const assignment = FieldAssignment(
      id: 'assignment-1',
      fieldIndex: 2,
      fieldHeader: 'email',
      selectedText: 'ana@example.com',
      path: DocumentTextPath(
        pageIndex: 0,
        steps: <DocumentPathStep>[
          DocumentPathStep.rootBlock(blockIndex: 1),
          DocumentPathStep.cellBlock(rowIndex: 0, cellIndex: 1, blockIndex: 0),
        ],
      ),
      startOffset: 4,
      endOffset: 19,
    );

    final json = mappingAssignmentsToJson(<FieldAssignment>[assignment]);
    final restored = mappingAssignmentsFromJson(json);

    expect(restored, <FieldAssignment>[assignment]);
  });
}
