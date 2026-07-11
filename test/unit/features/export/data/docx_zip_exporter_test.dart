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
  });
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
