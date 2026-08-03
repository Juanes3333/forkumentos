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

  test('serializa y restaura region header/footer', () {
    const assignment = FieldAssignment(
      id: 'assignment-2',
      fieldIndex: 0,
      fieldHeader: 'titulo',
      selectedText: 'Ana',
      path: DocumentTextPath(
        steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 0)],
        region: DocumentTextRegion.header,
      ),
      startOffset: 0,
      endOffset: 3,
    );

    final json = mappingAssignmentsToJson(<FieldAssignment>[assignment]);
    final restored = mappingAssignmentsFromJson(json);

    expect(restored, <FieldAssignment>[assignment]);
  });

  test(
    'un JSON de proyecto viejo sin la clave region se restaura como body',
    () {
      final legacyJson = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'assignment-1',
          'fieldIndex': 2,
          'fieldHeader': 'email',
          'selectedText': 'ana@example.com',
          'path': <String, dynamic>{
            'pageIndex': 0,
            'steps': <Map<String, dynamic>>[
              <String, dynamic>{'type': 'rootBlock', 'blockIndex': 1},
            ],
            // sin clave 'region': simula un proyecto .fork guardado antes de
            // que existiera el campo.
          },
          'startOffset': 4,
          'endOffset': 19,
        },
      ];

      final restored = mappingAssignmentsFromJson(legacyJson);

      expect(restored, hasLength(1));
      expect(restored.single.path.region, DocumentTextRegion.body);
    },
  );
}
