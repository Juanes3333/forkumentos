import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/document_text_catalog.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_validation.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  group('extractDocumentTextPlaceholders', () {
    test('extrae textos no vacios desde el modelo Document', () {
      final document = _documentWithTexts(<String>['Hola Ana', '   ']);

      final placeholders = extractDocumentTextPlaceholders(document);

      expect(placeholders, hasLength(1));
      expect(placeholders.single.text, 'Hola Ana');
    });
  });

  group('validateMappingAssignments', () {
    test('permite multiples asignaciones al mismo campo de datasource', () {
      final assignments = <FieldAssignment>[
        _assignment(id: 'a1', fieldIndex: 0),
        _assignment(id: 'a2', fieldIndex: 0, startOffset: 5, endOffset: 8),
      ];

      final result = validateMappingAssignments(
        assignments: assignments,
        datasourceHeaders: <String>['nombre'],
      );

      expect(result.isValid, isTrue);
      expect(result.missingFieldIndexes, isEmpty);
    });

    test('detecta campos sin asignacion', () {
      final result = validateMappingAssignments(
        assignments: <FieldAssignment>[_assignment(id: 'a1', fieldIndex: 1)],
        datasourceHeaders: <String>['nombre', 'correo'],
      );

      expect(result.missingFieldIndexes, <int>[0]);
      expect(result.isValid, isFalse);
    });

    test('detecta ids duplicados y solapamientos', () {
      final result = validateMappingAssignments(
        assignments: <FieldAssignment>[
          _assignment(id: 'a1', fieldIndex: 0, endOffset: 5),
          _assignment(id: 'a1', fieldIndex: 1, startOffset: 3, endOffset: 8),
        ],
        datasourceHeaders: <String>['nombre', 'correo'],
      );

      expect(result.duplicateAssignmentIds, <String>['a1']);
      expect(result.overlaps, hasLength(1));
      expect(result.isValid, isFalse);
    });
  });

  group('synchronizeMappingAssignments', () {
    test('actualiza headers y elimina campos que ya no existen', () {
      final synced = synchronizeMappingAssignments(
        assignments: <FieldAssignment>[
          _assignment(id: 'a1', fieldIndex: 0, fieldHeader: 'old'),
          _assignment(id: 'a2', fieldIndex: 2, fieldHeader: 'removed'),
        ],
        datasourceHeaders: <String>['nombre'],
      );

      expect(synced, hasLength(1));
      expect(synced.single.fieldHeader, 'nombre');
    });

    test('elimina asignaciones cuyo texto ya no coincide con el documento', () {
      final synced = synchronizeMappingAssignments(
        assignments: <FieldAssignment>[_assignment(id: 'a1', fieldIndex: 0)],
        datasourceHeaders: <String>['nombre'],
        document: _documentWithTexts(<String>['Eva']),
      );

      expect(synced, isEmpty);
    });
  });
}

const _path = DocumentTextPath(
  pageIndex: 0,
  steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 0)],
);

FieldAssignment _assignment({
  required String id,
  required int fieldIndex,
  String fieldHeader = 'nombre',
  String selectedText = 'Ana',
  int startOffset = 0,
  int endOffset = 3,
}) {
  return FieldAssignment(
    id: id,
    fieldIndex: fieldIndex,
    fieldHeader: fieldHeader,
    selectedText: selectedText,
    path: _path,
    startOffset: startOffset,
    endOffset: endOffset,
  );
}

Document _documentWithTexts(List<String> texts) {
  return Document(
    pages: <DocumentPage>[
      DocumentPage(
        number: 1,
        widthPoints: 612,
        heightPoints: 792,
        margins: const DocumentMargins(
          topPoints: 72,
          rightPoints: 72,
          bottomPoints: 72,
          leftPoints: 72,
        ),
        blocks: <DocumentBlock>[
          for (final text in texts)
            DocumentBlock.paragraph(
              DocumentParagraph(
                runs: <DocumentRun>[
                  DocumentRun(
                    text: text,
                    isBold: false,
                    isItalic: false,
                    isUnderlined: false,
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
    omissions: const <DocumentOmission>{},
  );
}
