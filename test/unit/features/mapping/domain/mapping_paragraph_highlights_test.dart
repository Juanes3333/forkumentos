import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_paragraph_highlights.dart';
import 'package:forkumentos/features/mapping/domain/text_occurrence.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  group('buildParagraphHighlights', () {
    test(
      'sin endPath, resalta solo startOffset..endOffset del propio párrafo',
      () {
        final document = _documentWithTexts(<String>['Hola Ana Pérez']);
        final assignment = FieldAssignment(
          id: 'a1',
          fieldIndex: 0,
          fieldHeader: 'nombre',
          selectedText: 'Ana',
          path: _rootPath(0),
          startOffset: 5,
          endOffset: 8,
        );

        final highlights = buildParagraphHighlights(
          path: _rootPath(0),
          assignments: <FieldAssignment>[assignment],
          suggestions: const <TextOccurrence>[],
          hoveredFieldIndex: null,
          activeFieldIndex: 0,
          document: document,
        );

        expect(highlights, hasLength(1));
        expect(highlights.single.startOffset, 5);
        expect(highlights.single.endOffset, 8);
        expect(highlights.single.isExtendedParagraph, isFalse);
      },
    );

    test('con endPath, el párrafo inicial pinta desde startOffset hasta su '
        'propio final (preserva el prefijo)', () {
      final document = _documentWithTexts(<String>[
        'Estimado Ana Pérez,',
        'Calle Falsa 123, Springfield',
      ]);
      final assignment = FieldAssignment(
        id: 'a1',
        fieldIndex: 0,
        fieldHeader: 'direccion',
        selectedText: 'Ana Pérez,\nCalle Falsa',
        path: _rootPath(0),
        startOffset: 'Estimado '.length,
        endPath: _rootPath(1),
        endOffset: 'Calle Falsa'.length,
      );

      final highlights = buildParagraphHighlights(
        path: _rootPath(0),
        assignments: <FieldAssignment>[assignment],
        suggestions: const <TextOccurrence>[],
        hoveredFieldIndex: null,
        activeFieldIndex: 0,
        document: document,
      );

      expect(highlights, hasLength(1));
      expect(highlights.single.startOffset, 'Estimado '.length);
      expect(highlights.single.endOffset, 'Estimado Ana Pérez,'.length);
    });

    test('con endPath, el párrafo final pinta desde 0 hasta endOffset '
        '(preserva el sufijo)', () {
      final document = _documentWithTexts(<String>[
        'Estimado Ana Pérez,',
        'Calle Falsa 123, Springfield',
      ]);
      final assignment = FieldAssignment(
        id: 'a1',
        fieldIndex: 0,
        fieldHeader: 'direccion',
        selectedText: 'Ana Pérez,\nCalle Falsa',
        path: _rootPath(0),
        startOffset: 'Estimado '.length,
        endPath: _rootPath(1),
        endOffset: 'Calle Falsa'.length,
      );

      final highlights = buildParagraphHighlights(
        path: _rootPath(1),
        assignments: <FieldAssignment>[assignment],
        suggestions: const <TextOccurrence>[],
        hoveredFieldIndex: null,
        activeFieldIndex: 0,
        document: document,
      );

      expect(highlights, hasLength(1));
      expect(highlights.single.startOffset, 0);
      expect(highlights.single.endOffset, 'Calle Falsa'.length);
    });

    test('con endPath, los párrafos estrictamente intermedios se pintan '
        'completos como extensión', () {
      final document = _documentWithTexts(<String>[
        'Inicio Ana',
        'Párrafo del medio',
        'Fin Springfield',
      ]);
      final assignment = FieldAssignment(
        id: 'a1',
        fieldIndex: 0,
        fieldHeader: 'direccion',
        selectedText: 'Ana\nPárrafo del medio\nFin',
        path: _rootPath(0),
        startOffset: 'Inicio '.length,
        endPath: _rootPath(2),
        endOffset: 'Fin'.length,
      );

      final highlights = buildParagraphHighlights(
        path: _rootPath(1),
        assignments: <FieldAssignment>[assignment],
        suggestions: const <TextOccurrence>[],
        hoveredFieldIndex: null,
        activeFieldIndex: 0,
        document: document,
      );

      expect(highlights, hasLength(1));
      expect(highlights.single.startOffset, 0);
      expect(highlights.single.endOffset, 'Párrafo del medio'.length);
      expect(highlights.single.isExtendedParagraph, isTrue);
    });

    test('un párrafo fuera del rango no recibe highlight', () {
      final document = _documentWithTexts(<String>[
        'Inicio Ana',
        'Fin Springfield',
        'Ajeno a todo',
      ]);
      final assignment = FieldAssignment(
        id: 'a1',
        fieldIndex: 0,
        fieldHeader: 'direccion',
        selectedText: 'Ana\nFin',
        path: _rootPath(0),
        startOffset: 'Inicio '.length,
        endPath: _rootPath(1),
        endOffset: 'Fin'.length,
      );

      final highlights = buildParagraphHighlights(
        path: _rootPath(2),
        assignments: <FieldAssignment>[assignment],
        suggestions: const <TextOccurrence>[],
        hoveredFieldIndex: null,
        activeFieldIndex: 0,
        document: document,
      );

      expect(highlights, isEmpty);
    });
  });
}

DocumentTextPath _rootPath(int blockIndex) {
  return DocumentTextPath(
    steps: <DocumentPathStep>[
      DocumentPathStep.rootBlock(blockIndex: blockIndex),
    ],
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
          for (final text in texts) _paragraphBlock(text),
        ],
      ),
    ],
    omissions: const <DocumentOmission>{},
  );
}

DocumentBlock _paragraphBlock(String text) {
  return DocumentBlock.paragraph(
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
  );
}
