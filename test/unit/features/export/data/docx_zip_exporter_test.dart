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
            pageIndex: 0,
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
            pageIndex: 0,
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
            pageIndex: 0,
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 0,
            endOffset: 4,
            text: 'Miguel',
          ),
          DocxTextReplacement(
            pageIndex: 0,
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 5,
            endOffset: 10,
            text: 'Martinez',
          ),
        ],
      );

      // Texto visible reconstruido: exacto, sin fragmentos de "Juan"/"Pérez".
      expect(_wTexts(documentXml).join(), 'Miguel Martinez');

      // Inspección del XML crudo (no solo el texto unido): el primer w:t
      // se queda con todo el texto fusionado y los otros tres quedan
      // vacíos - ninguno retiene un carácter del texto viejo.
      expect(_wTexts(documentXml), <String>['Miguel Martinez', '', '', '']);
      expect(documentXml, isNot(contains('Juan')));
      expect(documentXml, isNot(contains('Pérez')));
    });

    test('w:lastRenderedPageBreak divide el chunk: el campo anterior cae en '
        'pageIndex 0 y el posterior en pageIndex 1', () {
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
            pageIndex: 0,
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 0,
            endOffset: 4,
            text: 'Saludos',
          ),
          // Segundo chunk: los offsets son locales a su propio texto
          // ("Mundo"), igual que los que calcula el mapeo sobre el bloque
          // que ingesta emite para la página 1.
          DocxTextReplacement(
            pageIndex: 1,
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
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
      // Troceo resultante: el marcador inicial del primer párrafo cierra un
      // chunk vacío (página 0), así que "Antes" cae en la página 1; el
      // marcador intermedio del segundo párrafo deja "Hola " en la página 1
      // (bloque 1) y "Ana" en la página 2. El reemplazo apunta a "Ana".
      final documentXml = _exportDocumentXml(
        bodyContent: body,
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            pageIndex: 2,
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
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
            pageIndex: 0,
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
            pageIndex: 0,
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

      expect(_wTexts(documentXml), <String>['Primero Segundo', '']);
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
          // Offset 8 dentro del SEGUNDO chunk: "Nombre:" (7) + '\t' (1).
          DocxTextReplacement(
            pageIndex: 1,
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
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
            pageIndex: 0,
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
            pageIndex: 0,
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
            pageIndex: 0,
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 0,
            endOffset: 4,
            text: 'Miguel',
          ),
          DocxTextReplacement(
            pageIndex: 0,
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 4,
            endOffset: 9,
            text: 'Martinez',
          ),
        ],
      );

      expect(_wTexts(documentXml), <String>['MiguelMartinez', '']);
    });

    test('un reemplazo que cruza un gap de tab se recorta al grupo donde '
        'empieza sin corromper el texto ni lanzar', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:r><w:t>AB</w:t></w:r>
  <w:r><w:tab/></w:r>
  <w:r><w:t>CD</w:t></w:r>
</w:p>
''',
        replacements: const <DocxTextReplacement>[
          // Span patológico: empieza en "AB" (grupo 1) y su fin (4) cae
          // dentro de "CD" (grupo 2), cruzando el tab de en medio. No
          // debería ocurrir en la práctica (los campos se extraen de
          // texto visible contiguo), pero no debe crashear ni corromper.
          DocxTextReplacement(
            pageIndex: 0,
            steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
            startOffset: 1,
            endOffset: 4,
            text: 'XX',
          ),
        ],
      );

      // Se recorta al grupo donde empieza ("AB") y se descarta la cola
      // tras el gap: "CD" permanece intacto.
      expect(_wTexts(documentXml), <String>['AXX', 'CD']);
      expect(_countElements(documentXml, 'tab'), 1);
    });

    test('un chunk compuesto solo por un tab (sin texto editable) no lanza y '
        'queda intacto', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '<w:p><w:r><w:tab/></w:r></w:p>',
        replacements: const <DocxTextReplacement>[
          DocxTextReplacement(
            pageIndex: 0,
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

    test('w:pageBreakBefore corta página: el párrafo anterior queda en '
        'pageIndex 0 y el marcado en pageIndex 1', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p><w:r><w:t>Uno</w:t></w:r></w:p>
<w:p>
  <w:pPr><w:pageBreakBefore/></w:pPr>
  <w:r><w:t>Dos</w:t></w:r>
</w:p>
''',
        replacements: <DocxTextReplacement>[
          _rootField(pageIndex: 0, blockIndex: 0, text: 'A'),
          _rootField(pageIndex: 1, blockIndex: 0, text: 'B'),
        ],
      );

      // Sin el espejo, "Dos" caería en (página 0, bloque 1) y el reemplazo
      // dirigido a (página 1, bloque 0) no encontraría destino.
      expect(_wTexts(documentXml), <String>['A', 'B']);
    });

    test('w:pageBreakBefore en el PRIMER párrafo del cuerpo no genera una '
        'página vacía inicial', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:pPr><w:pageBreakBefore/></w:pPr>
  <w:r><w:t>Uno</w:t></w:r>
</w:p>
<w:p><w:r><w:t>Dos</w:t></w:r></w:p>
''',
        replacements: <DocxTextReplacement>[
          _rootField(pageIndex: 0, blockIndex: 0, text: 'A'),
          _rootField(pageIndex: 0, blockIndex: 1, text: 'B'),
        ],
      );

      expect(_wTexts(documentXml), <String>['A', 'B']);
    });

    test('w:pageBreakBefore tras un párrafo que ya cerró página con w:br '
        'avanza una sola vez', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p><w:r><w:t>Uno</w:t><w:br w:type="page"/></w:r></w:p>
<w:p>
  <w:pPr><w:pageBreakBefore/></w:pPr>
  <w:r><w:t>Dos</w:t></w:r>
</w:p>
''',
        replacements: <DocxTextReplacement>[
          _rootField(pageIndex: 0, blockIndex: 0, text: 'A'),
          _rootField(pageIndex: 1, blockIndex: 0, text: 'B'),
        ],
      );

      // Doble avance dejaría "Dos" en pageIndex 2 y sin reemplazar.
      expect(_wTexts(documentXml), <String>['A', 'B']);
    });

    test('w:pageBreakBefore tras un párrafo que ya cerró página con '
        'w:lastRenderedPageBreak avanza una sola vez', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p><w:r><w:t>Uno</w:t><w:lastRenderedPageBreak/></w:r></w:p>
<w:p>
  <w:pPr><w:pageBreakBefore/></w:pPr>
  <w:r><w:t>Dos</w:t></w:r>
</w:p>
''',
        replacements: <DocxTextReplacement>[
          _rootField(pageIndex: 0, blockIndex: 0, text: 'A'),
          _rootField(pageIndex: 1, blockIndex: 0, text: 'B'),
        ],
      );

      expect(_wTexts(documentXml), <String>['A', 'B']);
    });

    test('w:pageBreakBefore en el párrafo siguiente a una w:tbl corta '
        'página: la tabla no cierra página por sí sola', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:tbl>
  <w:tr><w:tc><w:p><w:r><w:t>Celda</w:t></w:r></w:p></w:tc></w:tr>
</w:tbl>
<w:p>
  <w:pPr><w:pageBreakBefore/></w:pPr>
  <w:r><w:t>Dos</w:t></w:r>
</w:p>
''',
        replacements: <DocxTextReplacement>[
          const DocxTextReplacement(
            pageIndex: 0,
            steps: <ExportPathStep>[
              ExportPathStep.rootBlock(blockIndex: 0),
              ExportPathStep.cellBlock(
                rowIndex: 0,
                cellIndex: 0,
                blockIndex: 0,
              ),
            ],
            startOffset: 0,
            endOffset: 5,
            text: 'A',
          ),
          _rootField(pageIndex: 1, blockIndex: 0, text: 'B'),
        ],
      );

      expect(_wTexts(documentXml), <String>['A', 'B']);
    });

    test('un w:sectPr intermedio sin w:type usa el default nextPage y corta '
        'página', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:pPr><w:sectPr/></w:pPr>
  <w:r><w:t>Uno</w:t></w:r>
</w:p>
<w:p><w:r><w:t>Dos</w:t></w:r></w:p>
''',
        replacements: <DocxTextReplacement>[
          _rootField(pageIndex: 0, blockIndex: 0, text: 'A'),
          _rootField(pageIndex: 1, blockIndex: 0, text: 'B'),
        ],
      );

      expect(_wTexts(documentXml), <String>['A', 'B']);
    });

    test('un w:sectPr intermedio con w:type nextPage corta página', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:pPr><w:sectPr><w:type w:val="nextPage"/></w:sectPr></w:pPr>
  <w:r><w:t>Uno</w:t></w:r>
</w:p>
<w:p><w:r><w:t>Dos</w:t></w:r></w:p>
''',
        replacements: <DocxTextReplacement>[
          _rootField(pageIndex: 0, blockIndex: 0, text: 'A'),
          _rootField(pageIndex: 1, blockIndex: 0, text: 'B'),
        ],
      );

      expect(_wTexts(documentXml), <String>['A', 'B']);
    });

    test('un w:sectPr intermedio con w:type continuous NO corta página', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:p>
  <w:pPr><w:sectPr><w:type w:val="continuous"/></w:sectPr></w:pPr>
  <w:r><w:t>Uno</w:t></w:r>
</w:p>
<w:p><w:r><w:t>Dos</w:t></w:r></w:p>
''',
        replacements: <DocxTextReplacement>[
          _rootField(pageIndex: 0, blockIndex: 0, text: 'A'),
          _rootField(pageIndex: 0, blockIndex: 1, text: 'B'),
        ],
      );

      expect(_wTexts(documentXml), <String>['A', 'B']);
    });

    test('w:pageBreakBefore dentro de una celda de tabla NO mueve pageIndex '
        '(espejo de respectPageBreakBefore: false)', () {
      final documentXml = _exportDocumentXml(
        bodyContent: '''
<w:tbl>
  <w:tr>
    <w:tc>
      <w:p><w:r><w:t>Uno</w:t></w:r></w:p>
      <w:p>
        <w:pPr><w:pageBreakBefore/></w:pPr>
        <w:r><w:t>Dos</w:t></w:r>
      </w:p>
    </w:tc>
  </w:tr>
</w:tbl>
<w:p><w:r><w:t>Tres</w:t></w:r></w:p>
''',
        replacements: <DocxTextReplacement>[
          for (var blockIndex = 0; blockIndex < 2; blockIndex++)
            DocxTextReplacement(
              pageIndex: 0,
              steps: <ExportPathStep>[
                const ExportPathStep.rootBlock(blockIndex: 0),
                ExportPathStep.cellBlock(
                  rowIndex: 0,
                  cellIndex: 0,
                  blockIndex: blockIndex,
                ),
              ],
              startOffset: 0,
              endOffset: 3,
              text: blockIndex == 0 ? 'A' : 'B',
            ),
          _rootField(pageIndex: 0, blockIndex: 1, endOffset: 4, text: 'C'),
        ],
      );

      expect(_wTexts(documentXml), <String>['A', 'B', 'C']);
    });
  });
}

/// Un reemplazo de un párrafo de primer nivel, que es el caso de la mayoría
/// de estas pruebas de paginación.
DocxTextReplacement _rootField({
  required int pageIndex,
  required int blockIndex,
  required String text,
  int startOffset = 0,
  int endOffset = 3,
}) {
  return DocxTextReplacement(
    pageIndex: pageIndex,
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

int _countElements(String documentXml, String localName) {
  return XmlDocument.parse(documentXml).descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == localName)
      .length;
}
