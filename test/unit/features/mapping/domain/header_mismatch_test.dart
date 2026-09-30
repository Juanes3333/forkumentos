import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/header_mismatch.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  group('detectHeaderMismatches', () {
    test('encabezados idénticos no reportan discrepancias', () {
      final mismatches = detectHeaderMismatches(
        newHeaders: const <String>['nombre', 'cedula'],
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'nombre'),
          _assignment('b', 1, 'cedula'),
        ],
      );

      expect(mismatches, isEmpty);
    });

    test('un encabezado cambiado agrupa todas sus asignaciones', () {
      final mismatches = detectHeaderMismatches(
        newHeaders: const <String>['nombre', 'cedulaContratista'],
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'nombre'),
          _assignment('b', 1, 'Tipo y numero - CC'),
          _assignment('c', 1, 'Tipo y numero - CC'),
        ],
      );

      expect(mismatches, hasLength(1));
      final mismatch = mismatches.single;
      expect(mismatch.fieldIndex, 1);
      expect(mismatch.expectedHeader, 'Tipo y numero - CC');
      expect(mismatch.actualHeader, 'cedulaContratista');
      expect(mismatch.affectedAssignmentIds, <String>['b', 'c']);
    });

    test('varias columnas cambiadas salen ordenadas por índice', () {
      final mismatches = detectHeaderMismatches(
        newHeaders: const <String>['A2', 'B', 'C2'],
        assignments: <FieldAssignment>[
          _assignment('c', 2, 'C'),
          _assignment('a', 0, 'A'),
          _assignment('b', 1, 'B'),
        ],
      );

      expect(mismatches.map((m) => m.fieldIndex), <int>[0, 2]);
    });

    test('columnas nuevas o fuera de rango se ignoran', () {
      final mismatches = detectHeaderMismatches(
        newHeaders: const <String>['nombre', 'extra'],
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'nombre'),
          _assignment('z', 5, 'perdida'),
        ],
      );

      expect(mismatches, isEmpty);
    });
  });

  test('applyHeaderMismatches renombra solo las asignaciones afectadas', () {
    final assignments = <FieldAssignment>[
      _assignment('a', 0, 'nombre'),
      _assignment('b', 1, 'viejo'),
    ];
    final mismatches = detectHeaderMismatches(
      newHeaders: const <String>['nombre', 'nuevo'],
      assignments: assignments,
    );

    final updated = applyHeaderMismatches(assignments, mismatches);

    expect(updated.map((a) => a.fieldHeader), <String>['nombre', 'nuevo']);
    expect(updated.first, same(assignments.first));
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
