import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/export/data/docx_zip_exporter.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:xml/xml.dart';

void main() {
  group('DocxZipExporter', () {
    test('reemplaza texto mapeado y conserva otras entradas del ZIP', () {
      final template = _buildDocxBytes(
        documentXml: _documentWithBody(
          '<w:p><w:r><w:t>Hola Ana</w:t></w:r></w:p>',
        ),
        extraEntries: const <String, String>{
          'word/header1.xml': '<w:hdr>HEADER_INTACT</w:hdr>',
        },
      );

      final result = const DocxZipExporter().applyReplacements(
        templateBytes: template,
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 5,
            endOffset: 8,
            text: 'Eva',
          ),
        ],
      );

      final archive = ZipDecoder().decodeBytes(result);
      final entries = <String, ArchiveFile>{
        for (final file in archive.files) file.name.toLowerCase(): file,
      };

      expect(entries.containsKey('word/header1.xml'), isTrue);
      final header = utf8.decode(
        entries['word/header1.xml']!.content as List<int>,
      );
      expect(header, contains('HEADER_INTACT'));

      final documentXml = utf8.decode(
        entries['word/document.xml']!.content as List<int>,
      );
      final xml = XmlDocument.parse(documentXml);
      final texts = xml.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 't')
          .map((element) => element.innerText)
          .join();
      expect(texts, 'Hola Eva');
    });

    test('un run dentro de w:ins se incluye como texto normal: el campo '
        'alcanza y reemplaza el texto insertado', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:r><w:t>Nombre:</w:t><w:tab/></w:r>
  <w:ins w:id="1" w:author="Ana" w:date="2024-01-01T00:00:00Z">
    <w:r><w:t>Juan</w:t></w:r>
  </w:ins>
</w:p>
''',
        replacements: const <DocxTextReplacement>[
          // Offset 8 tras "Nombre:" (7) + '\t' (1): el texto insertado cuenta
          // para los offsets como cualquier w:t normal.
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 8,
            endOffset: 12,
            text: 'Miguel',
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['Nombre:', 'Miguel']);
      expect(_countElements(documentXml, 'tab'), 1);
      expect(documentXml, contains('w:ins'));
      expect(documentXml, isNot(contains('Juan')));
    });

    test('un run dentro de w:del se excluye del texto y de los offsets: el '
        'campo salta el bloque borrado y alcanza el texto siguiente sin '
        'contar sus caracteres', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:r><w:t>Nombre:</w:t><w:tab/></w:r>
  <w:del w:id="1" w:author="Ana" w:date="2024-01-01T00:00:00Z">
    <w:r><w:delText>Juan</w:delText></w:r>
  </w:del>
  <w:r><w:t>Ana</w:t></w:r>
</w:p>
''',
        replacements: const <DocxTextReplacement>[
          // Offset 8 tras "Nombre:" (7) + '\t' (1): el texto borrado ("Juan")
          // no cuenta para los offsets, así que el campo alcanza "Ana"
          // directamente, como si el w:del no existiera.
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 8,
            endOffset: 11,
            text: 'Miguel',
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['Nombre:', 'Miguel']);
      expect(_countElements(documentXml, 'tab'), 1);
      // El run borrado no se toca en absoluto: sigue en el XML tal cual,
      // como exige el formato OOXML de control de cambios.
      expect(documentXml, contains('<w:delText>Juan</w:delText>'));
    });

    test('reemplaza texto dentro de celdas de tabla', () {
      final template = _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:tbl>
  <w:tr>
    <w:tc>
      <w:p><w:r><w:t>Nombre</w:t></w:r></w:p>
    </w:tc>
  </w:tr>
</w:tbl>
'''),
      );

      final result = const DocxZipExporter().applyReplacements(
        templateBytes: template,
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[
              ExportPathStep.rootBlock(blockIndex: 0),
              ExportPathStep.cellBlock(
                rowIndex: 0,
                cellIndex: 0,
                blockIndex: 0,
              ),
            ],
            startOffset: 0,
            endOffset: 6,
            text: 'Luis',
          ),
        ],
      );

      final archive = ZipDecoder().decodeBytes(result);
      final documentFile = archive.files.firstWhere(
        (file) => file.name.toLowerCase() == 'word/document.xml',
      );
      final documentXml = utf8.decode(documentFile.content as List<int>);
      expect(documentXml, contains('Luis'));
      expect(documentXml, isNot(contains('>Nombre<')));
    });

    test('reconstruye "Juan Pérez" -> "Miguel Martinez" cuando cada nombre '
        'está partido en dos runs', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:r><w:t>Ju</w:t></w:r>
  <w:r><w:t>an </w:t></w:r>
  <w:r><w:t>Pé</w:t></w:r>
  <w:r><w:t>rez</w:t></w:r>
</w:p>
''',
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 0,
            endOffset: 4,
            text: 'Miguel',
          ),
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 5,
            endOffset: 10,
            text: 'Martinez',
          ),
        ],
      );

      // Texto visible reconstruido: exacto, sin fragmentos de "Juan"/"Pérez".
      expect(_wTexts(documentXml).join(), 'Miguel Martinez');

      // El texto se reparte de vuelta a los runs originales según dónde
      // empezaba cada tramo: "Miguel" hereda el run 1 (donde empezaba "Ju"),
      // el espacio intacto se queda en el run 2, "Martinez" hereda el run 3.
      // Ningún w:t retiene un carácter del texto viejo.
      expect(_wTexts(documentXml), <String>['Miguel', ' ', 'Martinez', '']);
      expect(documentXml, isNot(contains('Juan')));
      expect(documentXml, isNot(contains('Pérez')));
    });

    test('párrafo normal/bold/normal: reemplazar solo el run bold deja los '
        'normales intactos y conserva su negrilla (Bug 4)', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:r><w:t>Estimado </w:t></w:r>
  <w:r><w:rPr><w:b/></w:rPr><w:t>Juan Perez</w:t></w:r>
  <w:r><w:t> presente</w:t></w:r>
</w:p>
''',
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 9,
            endOffset: 19,
            text: 'Ana',
          ),
        ],
      );

      expect(_wRunTexts(documentXml), <(String, bool)>[
        ('Estimado ', false),
        ('Ana', true),
        (' presente', false),
      ]);
    });

    test('párrafo bold/normal: reemplazar el run normal no toca el run bold '
        '(no se pierde ni se añade negrilla, Bug 4)', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:r><w:rPr><w:b/></w:rPr><w:t>NOMBRE: </w:t></w:r>
  <w:r><w:t>Juan</w:t></w:r>
</w:p>
''',
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 8,
            endOffset: 12,
            text: 'Ana Perez',
          ),
        ],
      );

      expect(_wRunTexts(documentXml), <(String, bool)>[
        ('NOMBRE: ', true),
        ('Ana Perez', false),
      ]);
    });

    test('w:lastRenderedPageBreak divide el chunk: los dos fragmentos del '
        'párrafo caen en índices de bloque absolutos consecutivos', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:r><w:t>Hola </w:t></w:r>
  <w:r><w:lastRenderedPageBreak /></w:r>
  <w:r><w:t>Mundo</w:t></w:r>
</w:p>
''',
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 0,
            endOffset: 4,
            text: 'Saludos',
          ),
          // Segundo chunk del MISMO párrafo: el índice absoluto avanzó una
          // vez al cerrar el primer chunk, así que este cae en blockIndex 1,
          // no en un blockIndex 0 de una "página" distinta.
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 1)],
            startOffset: 0,
            endOffset: 5,
            text: 'Planeta',
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['Saludos ', 'Planeta']);
      // El marcador que definió el corte no viaja al documento exportado.
      expect(_countElements(documentXml, 'lastRenderedPageBreak'), 0);
    });

    test('los w:lastRenderedPageBreak se eliminan del XML exportado sin '
        'cambiar un solo carácter visible', () {
      const body = '''
<w:p>
  <w:r><w:lastRenderedPageBreak /><w:t>Antes</w:t></w:r>
</w:p>
<w:p>
  <w:r><w:t>Hola </w:t><w:lastRenderedPageBreak /><w:t>Ana</w:t></w:r>
</w:p>
''';
      // Troceo resultante en índices absolutos: el marcador inicial del
      // primer párrafo cierra un chunk vacío (blockIndex 0), y "Antes" cae
      // en blockIndex 1; el marcador intermedio del segundo párrafo deja
      // "Hola " en blockIndex 2 y "Ana" en blockIndex 3. El reemplazo
      // apunta a "Ana".
      final documentXml = _exportDocumentXml(
        bodyContent: body,
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 3)],
            startOffset: 0,
            endOffset: 3,
            text: 'Eva',
          ),
        ],
      );

      expect(_countElements(documentXml, 'lastRenderedPageBreak'), 0);
      // Texto visible idéntico al que produciría el mismo reemplazo con los
      // marcadores presentes: quitarlos no aporta ni quita caracteres.
      expect(_wTexts(documentXml).join(), 'AntesHola Eva');
      // El run que solo contenía el marcador sigue existiendo, vacío y
      // válido: no aporta caracteres, así que no altera el texto plano.
      expect(_countElements(documentXml, 'r'), 2);
    });

    test('w:lastRenderedPageBreak dentro de una celda de tabla NO trocea el '
        'bloque: la celda sigue siendo un solo párrafo', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:tbl>
  <w:tr>
    <w:tc>
      <w:p>
        <w:r><w:t>Uno </w:t></w:r>
        <w:r><w:lastRenderedPageBreak /></w:r>
        <w:r><w:t>Dos</w:t></w:r>
      </w:p>
    </w:tc>
  </w:tr>
</w:tbl>
''',
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[
              ExportPathStep.rootBlock(blockIndex: 0),
              ExportPathStep.cellBlock(
                rowIndex: 0,
                cellIndex: 0,
                blockIndex: 0,
              ),
            ],
            startOffset: 0,
            endOffset: 3,
            text: 'Primero',
          ),
          // El bloque de tabla es atómico, así que el marcador se ignora y la
          // celda expone UN solo párrafo con el texto completo: los offsets
          // son continuos sobre "Uno Dos", igual que en ingesta
          // (`_isInsideTable` en docx_document_repository.dart). Un segundo
          // bloque de celda ya no existe.
          DocxTextReplacement(
            steps: <ExportPathStep>[
              ExportPathStep.rootBlock(blockIndex: 0),
              ExportPathStep.cellBlock(
                rowIndex: 0,
                cellIndex: 0,
                blockIndex: 0,
              ),
            ],
            startOffset: 4,
            endOffset: 7,
            text: 'Segundo',
          ),
        ],
      );

      // Cada reemplazo se queda en su run de origen; el espacio intacto
      // sigue en el primero.
      expect(_wTexts(documentXml), <String>['Primero ', 'Segundo']);
      expect(_countElements(documentXml, 'lastRenderedPageBreak'), 0);
    });

    test('un campo tras un w:tab en el chunk posterior al marcador conserva '
        'el tab y el offset del gap', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:r><w:t>Uno</w:t></w:r>
  <w:r><w:lastRenderedPageBreak /></w:r>
  <w:r><w:t>Nombre:</w:t><w:tab/><w:t>Juan</w:t></w:r>
</w:p>
''',
        replacements: const <DocxTextReplacement>[
          // Offset 8 dentro del SEGUNDO chunk (blockIndex 1 tras el corte):
          // "Nombre:" (7) + '\t' (1).
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 1)],
            startOffset: 8,
            endOffset: 12,
            text: 'Miguel',
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['Uno', 'Nombre:', 'Miguel']);
      expect(_countElements(documentXml, 'tab'), 1);
      expect(_countElements(documentXml, 'lastRenderedPageBreak'), 0);
      expect(documentXml, isNot(contains('Juan')));
    });

    test('un campo después de un w:tab conserva el tab y reemplaza el span '
        'correcto', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p><w:r><w:t>Nombre:</w:t><w:tab/><w:t>Juan</w:t></w:r></w:p>
''',
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 8,
            endOffset: 12,
            text: 'Miguel',
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['Nombre:', 'Miguel']);
      expect(_countElements(documentXml, 'tab'), 1);
      expect(_wTexts(documentXml).any((text) => text.contains('\t')), isFalse);
      expect(documentXml, isNot(contains('Juan')));
    });

    test('un campo después de un salto de línea manual (w:br) conserva el '
        'salto y reemplaza el span correcto', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p><w:r><w:t>Nombre:</w:t><w:br/><w:t>Juan</w:t></w:r></w:p>
''',
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 8,
            endOffset: 12,
            text: 'Miguel',
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['Nombre:', 'Miguel']);
      expect(_countElements(documentXml, 'br'), 1);
      expect(_wTexts(documentXml).any((text) => text.contains('\n')), isFalse);
      expect(documentXml, isNot(contains('Juan')));
    });

    test('dos campos consecutivos sin separador y alineados a un límite de '
        'run se reemplazan sin fugas en el límite', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p><w:r><w:t>Juan</w:t></w:r><w:r><w:t>Perez</w:t></w:r></w:p>
''',
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 0,
            endOffset: 4,
            text: 'Miguel',
          ),
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 4,
            endOffset: 9,
            text: 'Martinez',
          ),
        ],
      );

      // Cada campo reemplaza el texto de su propio run y se queda ahí.
      expect(_wTexts(documentXml), <String>['Miguel', 'Martinez']);
    });

    test(
      'un reemplazo que cruza un gap de tab escribe en el primer grupo, '
      'vacía la porción cubierta del siguiente y elimina el tab intermedio',
      () {
        final documentXml = _exportDocumentXml(
          bodyContent: '''
<w:p>
  <w:r><w:t>AB</w:t></w:r>
  <w:r><w:tab/></w:r>
  <w:r><w:t>CD</w:t></w:r>
</w:p>
''',
          replacements: const <DocxTextReplacement>[
            DocxTextReplacement(
              steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
              startOffset: 1,
              endOffset: 4,
              text: 'XX',
            ),
          ],
        );

        expect(_wTexts(documentXml), <String>['AXX', 'D']);
        expect(_countElements(documentXml, 'tab'), 0);
      },
    );

    test(
      'un reemplazo que cruza 3 o más grupos editables separados por tabs '
      'pone el texto en el primer grupo, vacía los demás y elimina los tabs',
      () {
        final documentXml = _exportDocumentXml(
          bodyContent: '''
<w:p>
  <w:r><w:t>AAA</w:t></w:r>
  <w:r><w:tab/></w:r>
  <w:r><w:t>BBB</w:t></w:r>
  <w:r><w:tab/></w:r>
  <w:r><w:t>CCC</w:t></w:r>
</w:p>
''',
          replacements: const <DocxTextReplacement>[
            // Total length: 3 ("AAA") + 1 (\t) + 3 ("BBB") + 1 (\t) + 3 ("CCC") = 11
            DocxTextReplacement(
              steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
              startOffset: 0,
              endOffset: 11,
              text: 'REPLACEMENT',
            ),
          ],
        );

        expect(_wTexts(documentXml), <String>['REPLACEMENT', '', '']);
        expect(_wTexts(documentXml).join(), 'REPLACEMENT');
        expect(_countElements(documentXml, 'tab'), 0);
      },
    );

    test('un chunk compuesto solo por un tab (sin texto editable) no lanza y '
        'queda intacto', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '<w:p><w:r><w:tab/></w:r></w:p>',
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 0,
            endOffset: 1,
            text: 'X',
          ),
        ],
      );

      expect(_wTexts(documentXml), isEmpty);
      expect(_countElements(documentXml, 'tab'), 1);
    });

    test('w:pageBreakBefore y w:sectPr son marcadores inertes para la '
        'exportación: no reinician nada, el índice de bloque sigue siendo '
        'puramente secuencial', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p><w:r><w:t>Uno</w:t></w:r></w:p>
<w:p>
  <w:pPr><w:pageBreakBefore/></w:pPr>
  <w:r><w:t>Dos</w:t></w:r>
</w:p>
<w:p>
  <w:pPr><w:sectPr><w:type w:val="nextPage"/></w:sectPr></w:pPr>
  <w:r><w:t>Tres</w:t></w:r>
</w:p>
<w:p><w:r><w:t>Cuatro</w:t></w:r></w:p>
''',
        replacements: <DocxTextReplacement>[
          _rootField(blockIndex: 0, text: 'A'),
          _rootField(blockIndex: 1, text: 'B'),
          _rootField(blockIndex: 2, endOffset: 4, text: 'C'),
          _rootField(blockIndex: 3, endOffset: 6, text: 'D'),
        ],
      );

      expect(_wTexts(documentXml), <String>['A', 'B', 'C', 'D']);
    });

    test('un documento sin marcadores de salto de página reemplaza '
        'correctamente campos en párrafos que la heurística de paginación del '
        'visor habría repartido en páginas distintas: el índice absoluto de '
        'bloque nunca depende de dónde caiga un límite de página estimado', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p><w:r><w:t>Uno</w:t></w:r></w:p>
<w:p><w:r><w:t>Dos</w:t></w:r></w:p>
<w:p><w:r><w:t>Tres</w:t></w:r></w:p>
<w:p><w:r><w:t>Cuatro</w:t></w:r></w:p>
<w:p><w:r><w:t>Cinco</w:t></w:r></w:p>
''',
        replacements: <DocxTextReplacement>[
          _rootField(blockIndex: 0, text: 'A'),
          _rootField(blockIndex: 2, endOffset: 4, text: 'C'),
          _rootField(blockIndex: 4, endOffset: 5, text: 'E'),
        ],
      );

      expect(_wTexts(documentXml), <String>['A', 'Dos', 'C', 'Cuatro', 'E']);
    });

    test('un campo de lista con menos líneas que ítems originales contrae la '
        'lista numerada sin dejar residuos de los ítems sobrantes', () {
      final documentXml = _exportDocumentXmlWithLists(
        bodyContent: _numberedListBody(itemCount: 8),
        listReplacements: const <DocxListReplacement>[
          DocxListReplacement(
            rootBlockIndex: 0,
            lines: <String>['Uno', 'Dos', 'Tres'],
            isNumberedList: true,
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['Uno', 'Dos', 'Tres']);
      expect(_countElements(documentXml, 'p'), 3);
      // Cada párrafo nuevo conserva el numId de la plantilla, así que Word
      // sigue numerando la lista automáticamente.
      expect(_numIds(documentXml), <int>[1, 1, 1]);
    });

    test('un campo de lista con más líneas que ítems originales expande la '
        'lista numerada clonando el párrafo plantilla', () {
      final lines = List<String>.generate(12, (i) => 'Item ${i + 1}');
      final documentXml = _exportDocumentXmlWithLists(
        bodyContent: _numberedListBody(itemCount: 8),
        listReplacements: <DocxListReplacement>[
          DocxListReplacement(
            rootBlockIndex: 0,
            lines: lines,
            isNumberedList: true,
          ),
        ],
      );

      expect(_wTexts(documentXml), lines);
      expect(_countElements(documentXml, 'p'), 12);
      expect(_numIds(documentXml), List<int>.filled(12, 1));
    });

    test(
      'un campo de lista convive con un reemplazo de texto normal en un '
      'párrafo posterior sin que la contracción de la lista lo desalinee',
      () {
        final documentXml = _exportDocumentXmlWithLists(
          bodyContent:
              '${_numberedListBody(itemCount: 8)}'
              '<w:p><w:r><w:t>Firma: XXX</w:t></w:r></w:p>',
          replacements: const <DocxTextReplacement>[
            // blockIndex 8: el noveno <w:p> del body, tras los 8 de la lista.
            DocxTextReplacement(
              steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 8)],
              startOffset: 7,
              endOffset: 10,
              text: 'Ana',
            ),
          ],
          listReplacements: const <DocxListReplacement>[
            DocxListReplacement(
              rootBlockIndex: 0,
              lines: <String>['Solo uno'],
              isNumberedList: true,
            ),
          ],
        );

        expect(_wTexts(documentXml), <String>['Solo uno', 'Firma: Ana']);
      },
    );

    test('un campo de prosa multi-párrafo (isNumberedList: false) colapsa '
        'paragraphSpan párrafos consecutivos a una sola línea, sin mirar '
        'w:numId', () {
      final documentXml = _exportDocumentXmlWithLists(
        bodyContent: '''
<w:p><w:r><w:t>Primer párrafo.</w:t></w:r></w:p>
<w:p><w:r><w:t>Segundo párrafo.</w:t></w:r></w:p>
''',
        listReplacements: const <DocxListReplacement>[
          DocxListReplacement(
            rootBlockIndex: 0,
            lines: <String>['Texto unificado.'],
            isNumberedList: false,
            paragraphSpan: 2,
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['Texto unificado.']);
      expect(_countElements(documentXml, 'p'), 1);
    });

    test('un campo de prosa multi-párrafo expande su rango de origen '
        '(paragraphSpan) a lines.length párrafos de salida, igual que el '
        'modo lista', () {
      final documentXml = _exportDocumentXmlWithLists(
        bodyContent: '''
<w:p><w:r><w:t>Uno.</w:t></w:r></w:p>
<w:p><w:r><w:t>Dos.</w:t></w:r></w:p>
''',
        listReplacements: const <DocxListReplacement>[
          DocxListReplacement(
            rootBlockIndex: 0,
            lines: <String>['A', 'B', 'C'],
            isNumberedList: false,
            paragraphSpan: 2,
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['A', 'B', 'C']);
      expect(_countElements(documentXml, 'p'), 3);
    });

    test('un campo de prosa multi-párrafo ignora w:numId por completo: dos '
        'párrafos con numId distinto igual se colapsan porque el rango es '
        'por paragraphSpan, no por lista', () {
      final documentXml = _exportDocumentXmlWithLists(
        bodyContent: '''
<w:p>
  <w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>
  <w:r><w:t>Uno.</w:t></w:r>
</w:p>
<w:p><w:r><w:t>Dos.</w:t></w:r></w:p>
''',
        listReplacements: const <DocxListReplacement>[
          DocxListReplacement(
            rootBlockIndex: 0,
            lines: <String>['Junto.'],
            isNumberedList: false,
            paragraphSpan: 2,
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['Junto.']);
      expect(_countElements(documentXml, 'p'), 1);
    });
  });

  group('DocxRangeReplacement (rango cruzado entre párrafos)', () {
    test('texto de una sola línea fusiona P1 y P2: conserva el prefijo de '
        'P1 y el sufijo de P2, elimina P2', () {
      final documentXml = _exportDocumentXmlWithRanges(
        bodyContent: '''
<w:p><w:r><w:t>Hola mundo</w:t></w:r></w:p>
<w:p><w:r><w:t>cruel y frio.</w:t></w:r></w:p>
''',
        rangeReplacements: const <DocxRangeReplacement>[
          DocxRangeReplacement(
            startBlockIndex: 0,
            // "Hola " (prefijo) | "mundo" (rango) empieza en offset 5.
            startOffset: 5,
            endBlockIndex: 1,
            // "cruel" (rango) | " y frio." (sufijo) termina en offset 5.
            endOffset: 5,
            text: 'Ana',
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['Hola Ana y frio.']);
      expect(_countElements(documentXml, 'p'), 1);
    });

    test('texto con \\n cruzando dos párrafos: P1 = prefijo + línea 0, '
        'P2 = línea 1 + sufijo, sin párrafos clonados', () {
      final documentXml = _exportDocumentXmlWithRanges(
        bodyContent: '''
<w:p><w:r><w:t>Estimado: </w:t></w:r></w:p>
<w:p><w:r><w:t>Fin de carta.</w:t></w:r></w:p>
''',
        rangeReplacements: const <DocxRangeReplacement>[
          DocxRangeReplacement(
            startBlockIndex: 0,
            startOffset: 10,
            endBlockIndex: 1,
            endOffset: 0,
            text: 'Primera línea.\nSegunda línea.',
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>[
        'Estimado: Primera línea.',
        'Segunda línea.Fin de carta.',
      ]);
      expect(_countElements(documentXml, 'p'), 2);
    });

    test('texto con \\n cruzando tres párrafos: el párrafo intermedio se '
        'elimina y se clona uno nuevo por cada línea intermedia', () {
      final documentXml = _exportDocumentXmlWithRanges(
        bodyContent: '''
<w:p><w:r><w:t>Prefijo-</w:t></w:r></w:p>
<w:p><w:r><w:t>ESTE PARRAFO SE BORRA ENTERO</w:t></w:r></w:p>
<w:p><w:r><w:t>-sufijo</w:t></w:r></w:p>
''',
        rangeReplacements: const <DocxRangeReplacement>[
          DocxRangeReplacement(
            startBlockIndex: 0,
            startOffset: 8,
            endBlockIndex: 2,
            endOffset: 0,
            text: 'Uno.\nDos.\nTres.',
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>[
        'Prefijo-Uno.',
        'Dos.',
        'Tres.-sufijo',
      ]);
      expect(_countElements(documentXml, 'p'), 3);
      expect(documentXml, isNot(contains('ESTE PARRAFO SE BORRA ENTERO')));
    });

    test('el rango cruzado convive con reemplazos normales en otros '
        'párrafos, sin desalinear sus blockIndex', () {
      final documentXml = _exportDocumentXmlWithRanges(
        bodyContent: '''
<w:p><w:r><w:t>Saludo</w:t></w:r></w:p>
<w:p><w:r><w:t>Uno.</w:t></w:r></w:p>
<w:p><w:r><w:t>Dos.</w:t></w:r></w:p>
<w:p><w:r><w:t>Despedida</w:t></w:r></w:p>
''',
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 0,
            endOffset: 6,
            text: 'Hola',
          ),
          DocxTextReplacement(
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 3)],
            startOffset: 0,
            endOffset: 9,
            text: 'Chau',
          ),
        ],
        rangeReplacements: const <DocxRangeReplacement>[
          DocxRangeReplacement(
            startBlockIndex: 1,
            startOffset: 0,
            endBlockIndex: 2,
            endOffset: 4,
            text: 'Junto.',
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['Hola', 'Junto.', 'Chau']);
    });
  });
}

/// Un reemplazo de un párrafo de primer nivel, que es el caso de la mayoría
/// de estas pruebas.
DocxTextReplacement _rootField({
  required int blockIndex,
  required String text,
  int startOffset = 0,
  int endOffset = 3,
}) {
  return DocxTextReplacement(
    steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: blockIndex)],
    startOffset: startOffset,
    endOffset: endOffset,
    text: text,
  );
}

String _documentWithBody(String bodyContent) {
  return '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $bodyContent
  </w:body>
</w:document>
''';
}

Uint8List _buildDocxBytes({
  required String documentXml,
  Map<String, String> extraEntries = const <String, String>{},
}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', '<Types />'))
    ..addFile(ArchiveFile.string('word/document.xml', documentXml));
  for (final entry in extraEntries.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }

  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('No se pudo codificar el ZIP DOCX de prueba.');
  }
  return Uint8List.fromList(encoded);
}

/// Construye un DOCX con [bodyContent], aplica [replacements] y devuelve el
/// `word/document.xml` crudo resultante, para inspección directa del XML.
String _exportDocumentXml({
  required String bodyContent,
  required List<DocxTextReplacement> replacements,
}) {
  final template = _buildDocxBytes(documentXml: _documentWithBody(bodyContent));
  final result = const DocxZipExporter().applyReplacements(
    templateBytes: template,
    replacements: replacements,
  );
  final archive = ZipDecoder().decodeBytes(result);
  final documentFile = archive.files.firstWhere(
    (file) => file.name.toLowerCase() == 'word/document.xml',
  );
  return utf8.decode(documentFile.content as List<int>);
}

/// Contenido de cada `<w:t>` en orden de documento.
List<String> _wTexts(String documentXml) {
  return XmlDocument.parse(documentXml).descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == 't')
      .map((element) => element.innerText)
      .toList();
}

/// `(texto del w:t, ¿el w:r que lo contiene está en negrilla?)` en orden de
/// documento. Un `<w:b/>` sin `w:val`, o con `w:val` distinto de `0`/`false`,
/// cuenta como negrilla.
List<(String, bool)> _wRunTexts(String documentXml) {
  final result = <(String, bool)>[];
  for (final t
      in XmlDocument.parse(documentXml).descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 't')) {
    final run = t.ancestors.whereType<XmlElement>().firstWhere(
      (element) => element.name.local == 'r',
    );
    var bold = false;
    for (final rPr in run.childElements.where((e) => e.name.local == 'rPr')) {
      for (final b in rPr.childElements.where((e) => e.name.local == 'b')) {
        final val = b.getAttribute('val') ?? b.getAttribute('w:val');
        bold = val != '0' && val != 'false';
      }
    }
    result.add((t.innerText, bold));
  }
  return result;
}

int _countElements(String documentXml, String localName) {
  return XmlDocument.parse(documentXml).descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == localName)
      .length;
}

/// Como [_exportDocumentXml] pero también acepta [listReplacements].
String _exportDocumentXmlWithLists({
  required String bodyContent,
  List<DocxTextReplacement> replacements = const <DocxTextReplacement>[],
  List<DocxListReplacement> listReplacements = const <DocxListReplacement>[],
}) {
  final template = _buildDocxBytes(documentXml: _documentWithBody(bodyContent));
  final result = const DocxZipExporter().applyReplacements(
    templateBytes: template,
    replacements: replacements,
    listReplacements: listReplacements,
  );
  final archive = ZipDecoder().decodeBytes(result);
  final documentFile = archive.files.firstWhere(
    (file) => file.name.toLowerCase() == 'word/document.xml',
  );
  return utf8.decode(documentFile.content as List<int>);
}

/// Como [_exportDocumentXml] pero también acepta [rangeReplacements].
String _exportDocumentXmlWithRanges({
  required String bodyContent,
  List<DocxTextReplacement> replacements = const <DocxTextReplacement>[],
  List<DocxRangeReplacement> rangeReplacements = const <DocxRangeReplacement>[],
}) {
  final template = _buildDocxBytes(documentXml: _documentWithBody(bodyContent));
  final result = const DocxZipExporter().applyReplacements(
    templateBytes: template,
    replacements: replacements,
    rangeReplacements: rangeReplacements,
  );
  final archive = ZipDecoder().decodeBytes(result);
  final documentFile = archive.files.firstWhere(
    (file) => file.name.toLowerCase() == 'word/document.xml',
  );
  return utf8.decode(documentFile.content as List<int>);
}

/// `bodyContent` de una lista numerada de [itemCount] ítems, cada uno un
/// `<w:p>` con `<w:numPr>` compartiendo `w:numId="1"`, como la lista de 8
/// ítems del template real que motiva esta feature.
String _numberedListBody({required int itemCount}) {
  final buffer = StringBuffer();
  for (var i = 1; i <= itemCount; i++) {
    buffer.write('''
<w:p>
  <w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>
  <w:r><w:t>Item $i</w:t></w:r>
</w:p>
''');
  }
  return buffer.toString();
}

/// `w:numId` de cada `<w:p>` en orden de documento (falta = se omite).
List<int> _numIds(String documentXml) {
  final ids = <int>[];
  for (final p in XmlDocument.parse(
    documentXml,
  ).descendants.whereType<XmlElement>().where((e) => e.name.local == 'p')) {
    for (final numId in p.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'numId',
    )) {
      for (final attr in numId.attributes) {
        if (attr.name.local == 'val') {
          ids.add(int.parse(attr.value));
        }
      }
    }
  }
  return ids;
}
