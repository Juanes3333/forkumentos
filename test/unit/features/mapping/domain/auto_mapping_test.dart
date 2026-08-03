import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/auto_mapping.dart';
import 'package:forkumentos/features/mapping/domain/document_text_catalog.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  group('buildAutoMapping', () {
    test('ancla una asignación por columna sobre el texto real', () {
      final document = _documentWithTexts(<String>[
        'Estimado Juan,',
        'Apellido: Pérez',
      ]);

      final result = buildAutoMapping(
        document: document,
        headers: <String>['Nombre', 'Apellido'],
        firstRow: <String?>['Juan', 'Pérez'],
        existingAssignments: const <FieldAssignment>[],
        generateId: _sequentialIds(),
      );

      expect(result.skippedCount, 0);
      expect(result.assignments, hasLength(2));

      final nombre = result.assignments.first;
      expect(nombre.id, 'id-0');
      expect(nombre.fieldIndex, 0);
      expect(nombre.fieldHeader, 'Nombre');
      expect(nombre.selectedText, 'Juan');
      expect(nombre.path, _bodyPath(0));
      // El anclaje se prueba cortando el párrafo real, no repitiendo literales.
      expect(_sliceAt(document, nombre), 'Juan');

      final apellido = result.assignments.last;
      expect(apellido.id, 'id-1');
      expect(apellido.fieldIndex, 1);
      expect(apellido.fieldHeader, 'Apellido');
      expect(apellido.path, _bodyPath(1));
      expect(_sliceAt(document, apellido), 'Pérez');
    });

    test('asigna todas las ocurrencias del mismo valor', () {
      final document = _documentWithTexts(<String>[
        'Hola Juan',
        'Firma: Juan',
        'Juan otra vez y Juan',
      ]);

      final result = buildAutoMapping(
        document: document,
        headers: <String>['Nombre'],
        firstRow: <String?>['Juan'],
        existingAssignments: const <FieldAssignment>[],
        generateId: _sequentialIds(),
      );

      expect(result.assignments, hasLength(4));
      expect(result.skippedCount, 0);
      for (final assignment in result.assignments) {
        expect(_sliceAt(document, assignment), 'Juan');
        expect(assignment.fieldIndex, 0);
      }
    });

    test('reporta el conteo real por columna, base del aviso al usuario', () {
      // 'A' es el caso peligroso: coincide en todas partes.
      final document = _documentWithTexts(<String>[
        'A A A A A A',
        'A A A A A A',
        'Contrato de Juan',
      ]);

      final result = buildAutoMapping(
        document: document,
        headers: <String>['Inicial', 'Nombre', 'Ausente'],
        firstRow: <String?>['A', 'Juan', 'Nadie'],
        existingAssignments: const <FieldAssignment>[],
        generateId: _sequentialIds(),
      );

      expect(result.occurrenceCountsByField, <int, int>{0: 12, 1: 1});
      expect(
        result.occurrenceCountsByField.containsKey(2),
        isFalse,
        reason: 'una columna sin coincidencias no aparece en el mapa',
      );
      expect(
        result.occurrenceCountsByField.values.reduce((a, b) => a + b),
        result.assignments.length,
      );
    });

    test('el conteo descuenta las ocurrencias solapadas', () {
      final document = _documentWithTexts(<String>['Juan', 'Juan otra vez']);
      final existing = <FieldAssignment>[
        FieldAssignment(
          id: 'previo',
          fieldIndex: 9,
          fieldHeader: 'Manual',
          selectedText: 'Juan',
          path: _bodyPath(0),
          startOffset: 0,
          endOffset: 4,
        ),
      ];

      final result = buildAutoMapping(
        document: document,
        headers: <String>['Nombre'],
        firstRow: <String?>['Juan'],
        existingAssignments: existing,
        generateId: _sequentialIds(),
      );

      expect(result.skippedCount, 1);
      expect(result.occurrenceCountsByField, <int, int>{0: 1});
    });

    test('salta valores nulos, vacíos o solo espacios', () {
      final document = _documentWithTexts(<String>['Juan   Pérez']);

      final result = buildAutoMapping(
        document: document,
        headers: <String>['Nulo', 'Vacio', 'Espacios', 'Nombre'],
        firstRow: <String?>[null, '', '   ', 'Juan'],
        existingAssignments: const <FieldAssignment>[],
        generateId: _sequentialIds(),
      );

      expect(result.assignments, hasLength(1));
      expect(result.assignments.single.fieldIndex, 3);
      expect(result.skippedCount, 0);
    });

    test('salta y cuenta las ocurrencias ya asignadas', () {
      final document = _documentWithTexts(<String>['Hola Juan', 'Y Juan']);
      final existing = <FieldAssignment>[
        FieldAssignment(
          id: 'previo',
          fieldIndex: 7,
          fieldHeader: 'Manual',
          selectedText: 'Juan',
          path: _bodyPath(0),
          startOffset: 5,
          endOffset: 9,
        ),
      ];

      final result = buildAutoMapping(
        document: document,
        headers: <String>['Nombre'],
        firstRow: <String?>['Juan'],
        existingAssignments: existing,
        generateId: _sequentialIds(),
      );

      expect(result.skippedCount, 1);
      expect(result.assignments, hasLength(1));
      expect(result.assignments.single.path, _bodyPath(1));
    });

    test('dos columnas con el mismo valor: gana la primera', () {
      final document = _documentWithTexts(<String>['Juan', 'Juan de nuevo']);

      final result = buildAutoMapping(
        document: document,
        headers: <String>['Nombre', 'Contacto'],
        firstRow: <String?>['Juan', 'Juan'],
        existingAssignments: const <FieldAssignment>[],
        generateId: _sequentialIds(),
      );

      expect(result.assignments, hasLength(2));
      expect(
        result.assignments.map((a) => a.fieldIndex),
        everyElement(0),
        reason: 'la segunda columna no debe reclamar tramos ya tomados',
      );
      expect(result.skippedCount, 2);
    });

    test('una subcadena de un valor ya anclado también se salta', () {
      final document = _documentWithTexts(<String>['Juan Pérez']);

      final result = buildAutoMapping(
        document: document,
        headers: <String>['Completo', 'Nombre'],
        firstRow: <String?>['Juan Pérez', 'Juan'],
        existingAssignments: const <FieldAssignment>[],
        generateId: _sequentialIds(),
      );

      expect(result.assignments, hasLength(1));
      expect(result.assignments.single.fieldIndex, 0);
      expect(result.skippedCount, 1);
    });

    test('no falla con cabeceras y fila de distinta longitud', () {
      final document = _documentWithTexts(<String>['Juan y Pérez']);

      final result = buildAutoMapping(
        document: document,
        headers: <String>['Nombre'],
        firstRow: <String?>['Juan', 'Pérez'],
        existingAssignments: const <FieldAssignment>[],
        generateId: _sequentialIds(),
      );

      expect(result.assignments, hasLength(1));
      expect(result.assignments.single.fieldHeader, 'Nombre');
    });
  });
}

String Function() _sequentialIds() {
  var next = 0;
  return () => 'id-${next++}';
}

/// Corta el párrafo real que apunta la asignación, para probar que el ancla
/// cae exactamente sobre el texto esperado.
String _sliceAt(Document document, FieldAssignment assignment) {
  final entry = enumerateParagraphTexts(
    document,
  ).firstWhere((entry) => entry.path == assignment.path);
  return entry.text.substring(assignment.startOffset, assignment.endOffset);
}

DocumentTextPath _bodyPath(int blockIndex) {
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
