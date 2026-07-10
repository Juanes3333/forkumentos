import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_review.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  group('buildMappingReviewSnapshot', () {
    test('marca export listo cuando no hay problemas', () {
      const secondPath = DocumentTextPath(
        pageIndex: 0,
        steps: <DocumentPathStep>[
          DocumentPathStep.rootBlock(blockIndex: 1),
        ],
      );
      final snapshot = buildMappingReviewSnapshot(
        assignments: <FieldAssignment>[
          _assignment(id: 'a1', fieldIndex: 0),
          _assignment(
            id: 'a2',
            fieldIndex: 1,
            fieldHeader: 'correo',
            selectedText: 'ana@example.com',
            path: secondPath,
            endOffset: 15,
          ),
        ],
        datasourceHeaders: <String>['nombre', 'correo'],
        document: _documentWithTexts(<String>['Ana', 'ana@example.com']),
      );

      expect(snapshot.isExportReady, isTrue);
      expect(snapshot.statistics.mappedFieldCount, 2);
      expect(snapshot.statistics.totalAssignments, 2);
      expect(snapshot.missingFieldHeaders, isEmpty);
      expect(snapshot.invalidAssignments, isEmpty);
    });

    test('detecta campos faltantes y bloquea export', () {
      final snapshot = buildMappingReviewSnapshot(
        assignments: <FieldAssignment>[_assignment(id: 'a1', fieldIndex: 0)],
        datasourceHeaders: <String>['nombre', 'correo'],
      );

      expect(snapshot.isExportReady, isFalse);
      expect(snapshot.missingFieldHeaders, <String>['correo']);
      expect(snapshot.statistics.pendingFieldCount, 1);
    });

    test('detecta asignaciones invalidas por desajuste con el documento', () {
      final snapshot = buildMappingReviewSnapshot(
        assignments: <FieldAssignment>[_assignment(id: 'a1', fieldIndex: 0)],
        datasourceHeaders: <String>['nombre'],
        document: _documentWithTexts(<String>['Eva']),
      );

      expect(snapshot.isExportReady, isFalse);
      expect(snapshot.invalidAssignments, hasLength(1));
      expect(snapshot.statistics.invalidAssignmentCount, 1);
    });

    test('incluye placeholders del documento para navegacion', () {
      final snapshot = buildMappingReviewSnapshot(
        assignments: <FieldAssignment>[_assignment(id: 'a1', fieldIndex: 0)],
        datasourceHeaders: <String>['nombre'],
        document: _documentWithTexts(<String>['Ana', 'Segundo párrafo']),
      );

      expect(snapshot.documentPlaceholders, hasLength(2));
      expect(snapshot.documentPlaceholders.first.text, 'Ana');
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
  DocumentTextPath path = _path,
}) {
  return FieldAssignment(
    id: id,
    fieldIndex: fieldIndex,
    fieldHeader: fieldHeader,
    selectedText: selectedText,
    path: path,
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
          for (var index = 0; index < texts.length; index++)
            DocumentBlock.paragraph(
              DocumentParagraph(
                runs: <DocumentRun>[
                  DocumentRun(
                    text: texts[index],
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
