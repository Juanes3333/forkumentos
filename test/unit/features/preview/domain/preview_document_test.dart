import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/preview/domain/preview_document.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  group('buildPreviewDocument', () {
    test('reemplaza el texto mapeado con el valor de la fila', () {
      final document = _twoPageDocument();
      final result = buildPreviewDocument(
        document: document,
        assignments: const <FieldAssignment>[
          FieldAssignment(
            id: 'a1',
            fieldIndex: 0,
            fieldHeader: 'nombre',
            selectedText: 'Ana',
            path: DocumentTextPath(
              steps: <DocumentPathStep>[
                DocumentPathStep.rootBlock(blockIndex: 0),
              ],
            ),
            startOffset: 5,
            endOffset: 8,
          ),
        ],
        headers: const <String>['nombre'],
        row: const <String?>['Eva'],
      );

      final paragraph =
          (result.pages[0].blocks[0] as DocumentParagraphBlock).paragraph;
      expect(paragraph.runs.map((run) => run.text).join(), 'Hola Eva');
    });

    test('deja intactos los párrafos sin asignación', () {
      final document = _twoPageDocument();
      final untouched = document.pages[0].blocks[1];
      final result = buildPreviewDocument(
        document: document,
        assignments: const <FieldAssignment>[
          FieldAssignment(
            id: 'a1',
            fieldIndex: 0,
            fieldHeader: 'nombre',
            selectedText: 'Ana',
            path: DocumentTextPath(
              steps: <DocumentPathStep>[
                DocumentPathStep.rootBlock(blockIndex: 0),
              ],
            ),
            startOffset: 5,
            endOffset: 8,
          ),
        ],
        headers: const <String>['nombre'],
        row: const <String?>['Eva'],
      );

      expect(identical(result.pages[0].blocks[1], untouched), isTrue);
      final second =
          (result.pages[0].blocks[1] as DocumentParagraphBlock).paragraph;
      expect(second.runs.map((run) => run.text).join(), 'Sin cambios');
    });

    test('reutiliza la misma instancia de páginas sin asignaciones', () {
      final document = _twoPageDocument();
      final pageWithoutAssignments = document.pages[1];
      final result = buildPreviewDocument(
        document: document,
        assignments: const <FieldAssignment>[
          FieldAssignment(
            id: 'a1',
            fieldIndex: 0,
            fieldHeader: 'nombre',
            selectedText: 'Ana',
            path: DocumentTextPath(
              steps: <DocumentPathStep>[
                DocumentPathStep.rootBlock(blockIndex: 0),
              ],
            ),
            startOffset: 5,
            endOffset: 8,
          ),
        ],
        headers: const <String>['nombre'],
        row: const <String?>['Eva'],
      );

      expect(identical(result.pages[1], pageWithoutAssignments), isTrue);
      expect(identical(result, document), isFalse);
    });

    test(
      'reemplaza un párrafo de la segunda página por su índice absoluto',
      () {
        final document = _twoPageDocument();
        final result = buildPreviewDocument(
          document: document,
          assignments: const <FieldAssignment>[
            FieldAssignment(
              id: 'a1',
              fieldIndex: 0,
              fieldHeader: 'nombre',
              selectedText: 'dos',
              // Absoluto: bloque 2 es "Página dos", el primero de la página 1
              // (la página 0 ya ocupa los índices 0 y 1). Si el offset
              // acumulado estuviera mal, esto pisaría "Hola Ana" o "Sin
              // cambios" en la página 0 en su lugar.
              path: DocumentTextPath(
                steps: <DocumentPathStep>[
                  DocumentPathStep.rootBlock(blockIndex: 2),
                ],
              ),
              startOffset: 7,
              endOffset: 10,
            ),
          ],
          headers: const <String>['nombre'],
          row: const <String?>['tres'],
        );

        final untouchedFirstPage = result.pages[0];
        expect(identical(untouchedFirstPage, document.pages[0]), isTrue);

        final paragraph =
            (result.pages[1].blocks[0] as DocumentParagraphBlock).paragraph;
        expect(paragraph.runs.map((run) => run.text).join(), 'Página tres');
      },
    );

    test('devuelve el mismo documento si no hay asignaciones', () {
      final document = _twoPageDocument();
      final result = buildPreviewDocument(
        document: document,
        assignments: const <FieldAssignment>[],
        headers: const <String>['nombre'],
        row: const <String?>['Eva'],
      );
      expect(identical(result, document), isTrue);
    });

    test('conserva las imágenes y el formato del párrafo al sustituir el '
        'texto mapeado', () {
      final document = _documentWithImageParagraph();
      final result = buildPreviewDocument(
        document: document,
        assignments: const <FieldAssignment>[
          FieldAssignment(
            id: 'a1',
            fieldIndex: 0,
            fieldHeader: 'nombre',
            selectedText: 'Ana',
            path: DocumentTextPath(
              steps: <DocumentPathStep>[
                DocumentPathStep.rootBlock(blockIndex: 0),
              ],
            ),
            startOffset: 5,
            endOffset: 8,
          ),
        ],
        headers: const <String>['nombre'],
        row: const <String?>['Eva'],
      );

      final paragraph =
          (result.pages[0].blocks[0] as DocumentParagraphBlock).paragraph;
      expect(paragraph.runs.map((run) => run.text).join(), 'Hola Eva!');
      // La imagen sigue entre "Hola Eva" y "!", en su posición original.
      expect(paragraph.runs.map((run) => run.image != null).toList(), <bool>[
        false,
        true,
        false,
      ]);
      expect(paragraph.alignment, DocumentAlignment.center);
      expect(paragraph.spacingAfterPoints, 10);
    });
  });
}

Document _documentWithImageParagraph() {
  return Document(
    omissions: const <DocumentOmission>{},
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
          DocumentBlock.paragraph(
            DocumentParagraph(
              runs: <DocumentRun>[
                const DocumentRun(
                  text: 'Hola Ana',
                  isBold: false,
                  isItalic: false,
                  isUnderlined: false,
                ),
                DocumentRun(
                  text: '',
                  isBold: false,
                  isItalic: false,
                  isUnderlined: false,
                  image: DocumentImage(
                    bytes: Uint8List.fromList(<int>[1, 2, 3]),
                    widthPoints: 20,
                    heightPoints: 10,
                  ),
                ),
                const DocumentRun(
                  text: '!',
                  isBold: false,
                  isItalic: false,
                  isUnderlined: false,
                ),
              ],
              alignment: DocumentAlignment.center,
              spacingAfterPoints: 10,
            ),
          ),
        ],
      ),
    ],
  );
}

Document _twoPageDocument() {
  const margins = DocumentMargins(
    topPoints: 72,
    rightPoints: 72,
    bottomPoints: 72,
    leftPoints: 72,
  );

  return const Document(
    omissions: <DocumentOmission>{},
    pages: <DocumentPage>[
      DocumentPage(
        number: 1,
        widthPoints: 612,
        heightPoints: 792,
        margins: margins,
        blocks: <DocumentBlock>[
          DocumentBlock.paragraph(
            DocumentParagraph(
              runs: <DocumentRun>[
                DocumentRun(
                  text: 'Hola Ana',
                  isBold: false,
                  isItalic: false,
                  isUnderlined: false,
                ),
              ],
            ),
          ),
          DocumentBlock.paragraph(
            DocumentParagraph(
              runs: <DocumentRun>[
                DocumentRun(
                  text: 'Sin cambios',
                  isBold: false,
                  isItalic: false,
                  isUnderlined: false,
                ),
              ],
            ),
          ),
        ],
      ),
      DocumentPage(
        number: 2,
        widthPoints: 612,
        heightPoints: 792,
        margins: margins,
        blocks: <DocumentBlock>[
          DocumentBlock.paragraph(
            DocumentParagraph(
              runs: <DocumentRun>[
                DocumentRun(
                  text: 'Página dos',
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
  );
}
