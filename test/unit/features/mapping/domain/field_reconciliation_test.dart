import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/field_reconciliation.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  group('buildFieldReconciliationItems', () {
    test('sin campos sin columna no hay nada que resolver', () {
      final items = buildFieldReconciliationItems(
        assignments: <FieldAssignment>[_assignment('a', 0, 'nombre')],
        headers: const <String>['nombre', 'correo'],
      );

      expect(items, isEmpty);
    });

    test('agrupa por nombre y cuenta los lugares donde se usa', () {
      final items = buildFieldReconciliationItems(
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'nombre'),
          _assignment('b', -1, 'cédula'),
          _assignment('c', -1, 'cédula'),
          _assignment('d', -1, 'teléfono'),
        ],
        headers: const <String>['nombre', 'x', 'y'],
      );

      expect(items.map((item) => item.orphanHeader), <String>[
        'cédula',
        'teléfono',
      ]);
      expect(items.map((item) => item.assignmentCount), <int>[2, 1]);
    });

    test('propone la única columna libre cuando hay un solo huérfano', () {
      final items = buildFieldReconciliationItems(
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'nombre'),
          _assignment('b', -1, 'cédula'),
        ],
        headers: const <String>['nombre', 'número de documento'],
      );

      expect(items.single.suggestedIndex, 1);
    });

    test('no propone columnas que ya usa otro campo', () {
      final items = buildFieldReconciliationItems(
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'nombre'),
          _assignment('b', 1, 'correo'),
          _assignment('c', -1, 'cédula'),
        ],
        headers: const <String>['nombre', 'correo'],
      );

      expect(items.single.suggestedIndex, isNull);
    });
  });
}

FieldAssignment _assignment(String id, int fieldIndex, String fieldHeader) {
  return FieldAssignment(
    id: id,
    fieldIndex: fieldIndex,
    fieldHeader: fieldHeader,
    selectedText: 'x',
    path: const DocumentTextPath(
      steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 0)],
    ),
    startOffset: 0,
    endOffset: 1,
  );
}
