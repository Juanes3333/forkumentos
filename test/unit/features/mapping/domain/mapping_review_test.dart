import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_review.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  group('buildMappingReviewSnapshot', () {
    test('marca export listo cuando no hay problemas', () {
      const secondPath = DocumentTextPath(
        steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 1)],
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

    test('permite export con campos faltantes (soft-gate)', () {
      final snapshot = buildMappingReviewSnapshot(
        assignments: <FieldAssignment>[_assignment(id: 'a1', fieldIndex: 0)],
        datasourceHeaders: <String>['nombre', 'correo'],
      );

      expect(snapshot.isExportReady, isTrue);
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

    test('una asignación con offsets ajustados al trim sigue coincidiendo '
        'aunque el párrafo tenga espacios extra alrededor', () {
      // Reproduce el invariante que confirmAssignment/replaceAssignment
      // deben mantener: selectedText ya viene trimmeado, así que sus
      // offsets deben apuntar solo al span sin espacios, no al drag
      // original con padding.
      final snapshot = buildMappingReviewSnapshot(
        assignments: <FieldAssignment>[
          _assignment(id: 'a1', fieldIndex: 0, startOffset: 2, endOffset: 5),
        ],
        datasourceHeaders: <String>['nombre'],
        document: _documentWithTexts(<String>['  Ana  ']),
      );

      expect(snapshot.invalidAssignments, isEmpty);
      expect(snapshot.isExportReady, isTrue);
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

    test('una asignación cuyo fieldIndex ahora nombra otra columna se marca '
        'inválida aunque el documento no haya cambiado', () {
      // Reproduce el bug de "desplazamiento de celdas": la fuente de datos
      // insertó una columna nueva antes de 'plazo' sin volver a mapear, así
      // que fieldIndex=1 (guardado para 'plazo') ahora apunta a 'valorNum'
      // en los headers actuales. El documento no cambió —
      // _stillMatchesDocument por sí solo no detectaría esto— pero el
      // header recordado sí difiere.
      final snapshot = buildMappingReviewSnapshot(
        assignments: <FieldAssignment>[
          _assignment(id: 'a1', fieldIndex: 1, fieldHeader: 'plazo'),
        ],
        datasourceHeaders: <String>['nombre', 'valorNum', 'plazo'],
        document: _documentWithTexts(<String>['Ana']),
      );

      expect(snapshot.isExportReady, isFalse);
      expect(snapshot.invalidAssignments, hasLength(1));
    });

    test(
      'un mismo pageIndex/steps en body y header no se confunden entre si',
      () {
        final document = _documentWithTexts(<String>['Otro']).copyWith(
          header: <DocumentBlock>[
            const DocumentBlock.paragraph(
              DocumentParagraph(
                runs: <DocumentRun>[
                  DocumentRun(
                    text: 'Ana',
                    isBold: false,
                    isItalic: false,
                    isUnderlined: false,
                  ),
                ],
              ),
            ),
          ],
        );

        // La asignación apunta a region body con el mismo pageIndex/steps
        // que la entrada de header ('Ana'), pero el texto del body en esa
        // ruta es 'Otro': debe marcarse inválida en vez de casar por error
        // contra el header.
        final snapshot = buildMappingReviewSnapshot(
          assignments: <FieldAssignment>[_assignment(id: 'a1', fieldIndex: 0)],
          datasourceHeaders: <String>['nombre'],
          document: document,
        );

        expect(snapshot.invalidAssignments, hasLength(1));

        // La misma asignación, pero apuntando a region header, sí es válida.
        final headerSnapshot = buildMappingReviewSnapshot(
          assignments: <FieldAssignment>[
            _assignment(
              id: 'a1',
              fieldIndex: 0,
              path: const DocumentTextPath(
                steps: <DocumentPathStep>[
                  DocumentPathStep.rootBlock(blockIndex: 0),
                ],
                region: DocumentTextRegion.header,
              ),
            ),
          ],
          datasourceHeaders: <String>['nombre'],
          document: document,
        );

        expect(headerSnapshot.invalidAssignments, isEmpty);
      },
    );

    test('una asignacion con rango cruzado entre parrafos (endPath) no crashea '
        'al revisar cuando endOffset (del parrafo final) es menor que '
        'startOffset (del parrafo inicial)', () {
      // Reproduce el RangeError original: `endOffset` pertenece al
      // parrafo de fin (`endPath`), no al de inicio, asi que comparar
      // `paragraphText.substring(startOffset, endOffset)` sobre el
      // parrafo de inicio lanzaba
      // `RangeError (end): Invalid value: Not in inclusive range 50..868: 1`.
      final longParagraph = 'x' * 868;
      final assignment = _assignment(
        id: 'a1',
        fieldIndex: 0,
        startOffset: 50,
        endOffset: 1,
        endPath: const DocumentTextPath(
          steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 1)],
        ),
      );

      expect(
        () => buildMappingReviewSnapshot(
          assignments: <FieldAssignment>[assignment],
          datasourceHeaders: <String>['nombre'],
          document: _documentWithTexts(<String>[longParagraph, 'y']),
        ),
        returnsNormally,
      );
    });
  });
}

const _path = DocumentTextPath(
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
  DocumentTextPath? endPath,
}) {
  return FieldAssignment(
    id: id,
    fieldIndex: fieldIndex,
    fieldHeader: fieldHeader,
    selectedText: selectedText,
    path: path,
    startOffset: startOffset,
    endOffset: endOffset,
    endPath: endPath,
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
