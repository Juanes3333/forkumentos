import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/field_insertion.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

DocumentTextPath root(int block, {DocumentTextRegion? region}) =>
    DocumentTextPath(
      steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: block)],
      region: region ?? DocumentTextRegion.body,
    );

FieldAssignment assignment(
  String id,
  int fieldIndex,
  DocumentTextPath path, {
  int start = 0,
}) {
  return FieldAssignment(
    id: id,
    fieldIndex: fieldIndex,
    fieldHeader: 'campo$fieldIndex',
    selectedText: 'x',
    path: path,
    startOffset: start,
    endOffset: start + 1,
  );
}

void main() {
  group('compareDocumentPositions', () {
    int compare(
      DocumentTextPath a,
      int offsetA,
      DocumentTextPath b,
      int offsetB,
    ) => compareDocumentPositions(
      pathA: a,
      offsetA: offsetA,
      pathB: b,
      offsetB: offsetB,
    );

    test('ordena por bloque y luego por desplazamiento', () {
      expect(compare(root(1), 5, root(2), 0), isNegative);
      expect(compare(root(3), 0, root(2), 9), isPositive);
      expect(compare(root(2), 3, root(2), 8), isNegative);
      expect(compare(root(2), 4, root(2), 4), isZero);
    });

    test('encabezado antes que cuerpo y cuerpo antes que pie', () {
      final header = root(9, region: DocumentTextRegion.header);
      final footer = root(0, region: DocumentTextRegion.footer);
      expect(compare(header, 0, root(0), 0), isNegative);
      expect(compare(footer, 0, root(5), 0), isPositive);
    });

    test('dentro de una tabla ordena por fila, celda y bloque', () {
      DocumentTextPath cell(int row, int col, int block) => DocumentTextPath(
        steps: <DocumentPathStep>[
          const DocumentPathStep.rootBlock(blockIndex: 4),
          DocumentPathStep.cellBlock(
            rowIndex: row,
            cellIndex: col,
            blockIndex: block,
          ),
        ],
      );
      expect(compare(cell(0, 1, 0), 0, cell(1, 0, 0), 0), isNegative);
      expect(compare(cell(1, 0, 2), 0, cell(1, 0, 1), 0), isPositive);
    });
  });

  group('insertionIndexForNewField', () {
    test('queda justo después de la columna del campo anterior en el '
        'documento (párrafo 1 y 3 mapeados, nuevo en el 2)', () {
      final index = insertionIndexForNewField(
        assignments: <FieldAssignment>[
          assignment('a', 0, root(1)),
          assignment('b', 1, root(3)),
        ],
        path: root(2),
        offset: 0,
        headerCount: 4,
      );

      expect(index, 1);
    });

    test('usa el campo anterior más cercano aunque haya otros antes', () {
      final index = insertionIndexForNewField(
        assignments: <FieldAssignment>[
          assignment('a', 0, root(0)),
          assignment('b', 3, root(2)),
          assignment('c', 1, root(5)),
        ],
        path: root(4),
        offset: 0,
        headerCount: 5,
      );

      expect(index, 4);
    });

    test('sin campo anterior queda justo antes del primero que va después', () {
      final index = insertionIndexForNewField(
        assignments: <FieldAssignment>[
          assignment('a', 2, root(4)),
          assignment('b', 3, root(6)),
        ],
        path: root(1),
        offset: 0,
        headerCount: 5,
      );

      expect(index, 2);
    });

    test('sin campos mapeados va al final', () {
      expect(
        insertionIndexForNewField(
          assignments: const <FieldAssignment>[],
          path: root(1),
          offset: 0,
          headerCount: 3,
        ),
        3,
      );
    });

    test('los campos sin columna no cuentan', () {
      expect(
        insertionIndexForNewField(
          assignments: <FieldAssignment>[assignment('a', -1, root(0))],
          path: root(3),
          offset: 0,
          headerCount: 2,
        ),
        2,
      );
    });

    test('en el mismo párrafo ordena por desplazamiento', () {
      final index = insertionIndexForNewField(
        assignments: <FieldAssignment>[
          assignment('a', 0, root(2)),
          assignment('b', 1, root(2), start: 20),
        ],
        path: root(2),
        offset: 10,
        headerCount: 3,
      );

      expect(index, 1);
    });
  });
}
