import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/document_text_catalog.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  group('findExactTextOccurrences', () {
    test('encuentra coincidencias exactas en párrafos', () {
      final document = _documentWithTexts(<String>['Hola Ana', 'Ana Pérez']);

      final occurrences = findExactTextOccurrences(
        document: document,
        needle: 'Ana',
      );

      expect(occurrences, hasLength(2));
      expect(occurrences.first.startOffset, 5);
      expect(occurrences.last.path.pageIndex, 0);
    });

    test('ignora needle vacío', () {
      final document = _documentWithTexts(<String>['Hola']);

      expect(
        findExactTextOccurrences(document: document, needle: '   '),
        isEmpty,
      );
    });
  });

  group('findOverlappingAssignment', () {
    test('detecta solapamiento en el mismo párrafo', () {
      const path = DocumentTextPath(
        pageIndex: 0,
        steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 0)],
      );
      final assignments = <FieldAssignment>[
        const FieldAssignment(
          id: 'a1',
          fieldIndex: 0,
          fieldHeader: 'nombre',
          selectedText: 'Ana',
          path: path,
          startOffset: 5,
          endOffset: 8,
        ),
      ];

      final conflict = findOverlappingAssignment(
        assignments: assignments,
        path: path,
        startOffset: 6,
        endOffset: 9,
      );

      expect(conflict?.id, 'a1');
    });

    test('no detecta conflicto en párrafos distintos', () {
      const pathA = DocumentTextPath(
        pageIndex: 0,
        steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 0)],
      );
      const pathB = DocumentTextPath(
        pageIndex: 0,
        steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 1)],
      );
      final assignments = <FieldAssignment>[
        const FieldAssignment(
          id: 'a1',
          fieldIndex: 0,
          fieldHeader: 'nombre',
          selectedText: 'Ana',
          path: pathA,
          startOffset: 0,
          endOffset: 3,
        ),
      ];

      final conflict = findOverlappingAssignment(
        assignments: assignments,
        path: pathB,
        startOffset: 0,
        endOffset: 3,
      );

      expect(conflict, isNull);
    });
  });
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
