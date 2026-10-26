import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_validation.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

DocumentTextPath _root(int block) => DocumentTextPath(
  steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: block)],
);

DocumentTextPath _cell(int row, int cell, int block) => DocumentTextPath(
  steps: <DocumentPathStep>[
    const DocumentPathStep.rootBlock(blockIndex: 1),
    DocumentPathStep.cellBlock(
      rowIndex: row,
      cellIndex: cell,
      blockIndex: block,
    ),
  ],
);

FieldAssignment _range(DocumentTextPath start, DocumentTextPath end) {
  return FieldAssignment(
    id: 'a',
    fieldIndex: 0,
    fieldHeader: 'campo',
    selectedText: 'x',
    path: start,
    startOffset: 0,
    endOffset: 2,
    endPath: end,
  );
}

void main() {
  group('assignmentStillMatchesDocument (contenedor del rango)', () {
    final texts = <DocumentTextPath, String>{
      _root(0): 'abc',
      _root(2): 'abc',
      _cell(0, 0, 0): 'abc',
      _cell(0, 0, 1): 'abc',
      _cell(0, 1, 0): 'abc',
    };

    test('acepta un rango entre dos párrafos de la misma celda', () {
      expect(
        assignmentStillMatchesDocument(
          _range(_cell(0, 0, 0), _cell(0, 0, 1)),
          texts,
        ),
        isTrue,
      );
    });

    test('acepta un rango entre dos párrafos raíz', () {
      expect(
        assignmentStillMatchesDocument(_range(_root(0), _root(2)), texts),
        isTrue,
      );
    });

    test('rechaza un rango que termina en otra celda', () {
      expect(
        assignmentStillMatchesDocument(
          _range(_cell(0, 0, 0), _cell(0, 1, 0)),
          texts,
        ),
        isFalse,
      );
    });

    test('rechaza un rango que mezcla raíz y celda', () {
      expect(
        assignmentStillMatchesDocument(_range(_root(0), _cell(0, 0, 1)), texts),
        isFalse,
      );
    });

    test('rechaza un rango cuyo fin está antes del inicio', () {
      expect(
        assignmentStillMatchesDocument(
          _range(_cell(0, 0, 1), _cell(0, 0, 0)),
          texts,
        ),
        isFalse,
      );
    });
  });
}
