import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/header_remap.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  group('normalizeHeader', () {
    test('ignora mayúsculas, tildes y espacios de más', () {
      expect(normalizeHeader('  Cédula  '), 'cedula');
      expect(normalizeHeader('TELÉFONO móvil'), 'telefono movil');
      expect(normalizeHeader('Número   de  documento'), 'numero de documento');
    });

    test('conserva la eñe porque cambia el significado', () {
      expect(normalizeHeader('Año'), 'año');
      expect(normalizeHeader('Año'), isNot(normalizeHeader('Ano')));
    });
  });

  group('remapAssignmentsToHeaders', () {
    test('una columna insertada en medio reubica los campos por nombre', () {
      // nombre | teléfono | cédula | correo  ->  con "tipo de documento".
      final result = remapAssignmentsToHeaders(
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'nombre'),
          _assignment('b', 1, 'teléfono'),
          _assignment('c', 2, 'cédula'),
          _assignment('d', 3, 'correo'),
        ],
        headers: const <String>[
          'nombre',
          'teléfono',
          'tipo de documento',
          'cédula',
          'correo',
        ],
      );

      expect(result.assignments.map((a) => a.fieldIndex), <int>[0, 1, 3, 4]);
      expect(result.assignments.map((a) => a.fieldHeader), <String>[
        'nombre',
        'teléfono',
        'cédula',
        'correo',
      ]);
      expect(result.orphanHeaders, isEmpty);
      expect(result.changed, isTrue);
    });

    test('un reorden de columnas reubica los campos', () {
      final result = remapAssignmentsToHeaders(
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'A'),
          _assignment('b', 1, 'B'),
          _assignment('c', 2, 'C'),
        ],
        headers: const <String>['C', 'A', 'B'],
      );

      expect(result.assignments.map((a) => a.fieldIndex), <int>[1, 2, 0]);
      expect(result.orphanHeaders, isEmpty);
    });

    test('sin cambios devuelve las mismas asignaciones y changed false', () {
      final input = <FieldAssignment>[
        _assignment('a', 0, 'nombre'),
        _assignment('b', 1, 'cedula'),
      ];
      final result = remapAssignmentsToHeaders(
        assignments: input,
        headers: const <String>['nombre', 'cedula', 'extra'],
      );

      expect(result.changed, isFalse);
      expect(result.assignments, input);
      expect(result.orphanHeaders, isEmpty);
    });

    test('varias asignaciones de un mismo campo se reubican juntas', () {
      final result = remapAssignmentsToHeaders(
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'nombre'),
          _assignment('b', 0, 'nombre'),
        ],
        headers: const <String>['id', 'nombre'],
      );

      expect(result.assignments.map((a) => a.fieldIndex), <int>[1, 1]);
    });

    test(
      'una columna eliminada deja el campo huérfano y conserva su nombre',
      () {
        final result = remapAssignmentsToHeaders(
          assignments: <FieldAssignment>[
            _assignment('a', 0, 'nombre'),
            _assignment('b', 1, 'cédula'),
            _assignment('c', 1, 'cédula'),
          ],
          headers: const <String>['nombre', 'correo'],
        );

        expect(result.assignments.map((a) => a.fieldIndex), <int>[0, -1, -1]);
        expect(result.assignments.map((a) => a.fieldHeader), <String>[
          'nombre',
          'cédula',
          'cédula',
        ]);
        expect(result.orphanHeaders, <String>['cédula']);
      },
    );

    test('un cambio cosmético de nombre se reconoce y adopta la escritura', () {
      final result = remapAssignmentsToHeaders(
        assignments: <FieldAssignment>[
          _assignment('a', 1, 'Cédula'),
          _assignment('b', 2, 'teléfono '),
        ],
        headers: const <String>['nombre', 'cedula', 'TELEFONO'],
      );

      expect(result.assignments.map((a) => a.fieldIndex), <int>[1, 2]);
      expect(result.assignments.map((a) => a.fieldHeader), <String>[
        'cedula',
        'TELEFONO',
      ]);
      expect(result.orphanHeaders, isEmpty);
    });

    test('una coincidencia exacta gana a una normalizada de otro campo', () {
      // "cedula" existe exacta; "Cédula" normaliza igual pero esa columna ya
      // está reservada por la exacta, así que "Cédula" queda huérfana.
      final result = remapAssignmentsToHeaders(
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'cedula'),
          _assignment('b', 1, 'Cédula'),
        ],
        headers: const <String>['cedula', 'otro'],
      );

      expect(result.assignments.map((a) => a.fieldIndex), <int>[0, -1]);
      expect(result.orphanHeaders, <String>['Cédula']);
    });

    test('dos nombres antiguos que normalizan igual no se adivinan', () {
      final result = remapAssignmentsToHeaders(
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'Cédula'),
          _assignment('b', 1, 'cedula '),
        ],
        headers: const <String>['CEDULA', 'x'],
      );

      expect(result.assignments.map((a) => a.fieldIndex), <int>[-1, -1]);
      expect(result.orphanHeaders, <String>['Cédula', 'cedula ']);
    });

    test('un huérfano vuelve a enlazarse cuando su columna reaparece', () {
      final orphan = _assignment('a', -1, 'cédula');
      final result = remapAssignmentsToHeaders(
        assignments: <FieldAssignment>[orphan],
        headers: const <String>['nombre', 'cédula'],
      );

      expect(result.assignments.single.fieldIndex, 1);
      expect(result.orphanHeaders, isEmpty);
      expect(result.changed, isTrue);
    });

    test('es idempotente', () {
      final first = remapAssignmentsToHeaders(
        assignments: <FieldAssignment>[
          _assignment('a', 0, 'Cédula'),
          _assignment('b', 1, 'vieja'),
        ],
        headers: const <String>['x', 'cedula'],
      );
      final second = remapAssignmentsToHeaders(
        assignments: first.assignments,
        headers: const <String>['x', 'cedula'],
      );

      expect(second.changed, isFalse);
      expect(second.assignments, first.assignments);
      expect(second.orphanHeaders, first.orphanHeaders);
    });

    test('sin asignaciones no hay cambios', () {
      final result = remapAssignmentsToHeaders(
        assignments: const <FieldAssignment>[],
        headers: const <String>['a', 'b'],
      );

      expect(result.changed, isFalse);
      expect(result.assignments, isEmpty);
      expect(result.orphanHeaders, isEmpty);
    });
  });

  group('assignmentsMatchHeaders', () {
    test('acepta índices que nombran su columna y campos sin columna', () {
      expect(
        assignmentsMatchHeaders(
          assignments: <FieldAssignment>[
            _assignment('a', 0, 'nombre'),
            _assignment('b', 2, 'correo'),
            _assignment('c', -1, 'cédula'),
          ],
          headers: const <String>['nombre', 'x', 'correo'],
        ),
        isTrue,
      );
    });

    test('rechaza un índice que ahora nombra otra columna', () {
      expect(
        assignmentsMatchHeaders(
          assignments: <FieldAssignment>[_assignment('a', 1, 'cédula')],
          headers: const <String>['nombre', 'tipo', 'cédula'],
        ),
        isFalse,
      );
    });

    test('rechaza un índice fuera de rango', () {
      expect(
        assignmentsMatchHeaders(
          assignments: <FieldAssignment>[_assignment('a', 5, 'x')],
          headers: const <String>['x'],
        ),
        isFalse,
      );
    });
  });

  group('suggestRenamedColumns', () {
    test('un huérfano y una columna libre se proponen entre sí', () {
      final suggestions = suggestRenamedColumns(
        orphanHeaders: const <String>['cédula'],
        headers: const <String>['nombre', 'número de documento', 'correo'],
        claimedIndexes: const <int>{0, 2},
      );

      expect(suggestions, <String, int>{'cédula': 1});
    });

    test('con varias columnas libres no adivina si no hay parecido', () {
      final suggestions = suggestRenamedColumns(
        orphanHeaders: const <String>['cédula'],
        headers: const <String>['nombre', 'ciudad', 'barrio'],
        claimedIndexes: const <int>{0},
      );

      expect(suggestions, isEmpty);
    });

    test('propone la única columna libre cuyo nombre contiene al huérfano', () {
      final suggestions = suggestRenamedColumns(
        orphanHeaders: const <String>['cédula', 'teléfono'],
        headers: const <String>[
          'nombre',
          'Cédula de ciudadanía',
          'barrio',
          'ciudad',
        ],
        claimedIndexes: const <int>{0},
      );

      expect(suggestions, <String, int>{'cédula': 1});
    });

    test('una misma columna propuesta a dos huérfanos no se propone', () {
      final suggestions = suggestRenamedColumns(
        orphanHeaders: const <String>['nombre', 'nombre completo'],
        headers: const <String>['id', 'nombre completo y apellidos', 'otra'],
        claimedIndexes: const <int>{0},
      );

      expect(suggestions, isEmpty);
    });

    test('nunca propone columnas que ya usa otro campo', () {
      final suggestions = suggestRenamedColumns(
        orphanHeaders: const <String>['cédula'],
        headers: const <String>['cédula de ciudadanía', 'otra'],
        claimedIndexes: const <int>{0, 1},
      );

      expect(suggestions, isEmpty);
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
