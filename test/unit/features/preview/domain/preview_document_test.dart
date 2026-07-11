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
              pageIndex: 0,
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
              pageIndex: 0,
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
              pageIndex: 0,
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
  });
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
