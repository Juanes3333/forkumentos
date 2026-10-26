import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/export/data/docx_export_command.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';
import 'package:forkumentos/features/mapping/domain/document_text_catalog.dart';
import 'package:forkumentos/shared/data/docx_document_repository.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:path/path.dart' as p;

/// Paridad ingesta ↔ exportador con la señal "esta tabla abre página": el
/// marcador solo mueve el corte de página de la vista, así que la ruta que
/// calcula la ingesta y el párrafo que reemplaza el exportador no cambian.
void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_page_signal_parity_',
    );
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  Future<({int pageCount, String documentXml})> loadAndExport({
    required String marker,
  }) async {
    final templatePath = p.join(tempDirectory.path, 'plantilla.docx');
    await File(templatePath).writeAsBytes(_template(marker: marker));

    final document = await const DocxDocumentRepository().load(templatePath);
    final occurrences = findExactTextOccurrences(
      document: document,
      needle: 'Eva',
    );
    expect(occurrences, hasLength(1));
    final occurrence = occurrences.single;
    final step = occurrence.path.steps.single as RootDocumentBlockStep;
    // Párrafo, tabla, párrafo: el que se mapea es el bloque raíz 2 con o sin
    // el marcador, porque la clave no depende de dónde corta la vista.
    expect(step.blockIndex, 2);

    final command = DocxExportCommand(
      templateBytes: File(templatePath).readAsBytesSync(),
      destinationFolder: tempDirectory.path,
      filenamePattern: const FilenamePattern(
        blocks: <FilenamePatternBlock>[
          FilenameFieldBlock(fieldIndex: 0, fieldHeader: 'nombre'),
        ],
      ),
      rowIndexes: const <int>[0],
      placeholders: <ExportPlaceholder>[
        ExportPlaceholder(
          steps: <ExportPathStep>[
            ExportPathStep.rootBlock(blockIndex: step.blockIndex),
          ],
          startOffset: occurrence.startOffset,
          endOffset: occurrence.endOffset,
          fieldIndex: 0,
        ),
      ],
      headers: const <String>['nombre'],
      templateBaseName: 'plantilla',
      resolveRow: (rowIndex) async => const <String?>['Ana'],
    );
    final result = await command.execute();
    expect(result.exportedCount, 1);
    expect(result.failedCount, 0);

    final archive = ZipDecoder().decodeBytes(
      File(result.writtenFiles.single).readAsBytesSync(),
    );
    final xml = utf8.decode(
      archive.files
              .firstWhere((file) => file.name == 'word/document.xml')
              .content
          as List<int>,
    );
    return (pageCount: document.pages.length, documentXml: xml);
  }

  test('con el marcador de apertura de página la vista corta antes de la '
      'tabla y el export reemplaza el mismo párrafo', () async {
    final withMarker = await loadAndExport(
      marker: '<w:lastRenderedPageBreak />',
    );

    expect(withMarker.pageCount, 2);
    expect(withMarker.documentXml, contains('Hola Ana'));
    expect(withMarker.documentXml, isNot(contains('Hola Eva')));
    expect(withMarker.documentXml, isNot(contains('lastRenderedPageBreak')));
  });

  test(
    'sin el marcador la ruta y el resultado del export son los mismos',
    () async {
      final withoutMarker = await loadAndExport(marker: '');

      expect(withoutMarker.pageCount, 1);
      expect(withoutMarker.documentXml, contains('Hola Ana'));
    },
  );
}

List<int> _template({required String marker}) {
  final documentXml =
      '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Antes</w:t></w:r></w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r>$marker<w:t>Celda</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
    <w:p><w:r><w:t>Hola Eva</w:t></w:r></w:p>
  </w:body>
</w:document>
''';
  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', documentXml))
    ..addFile(ArchiveFile.string('[Content_Types].xml', '<Types/>'));
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('No se pudo codificar el DOCX de prueba.');
  }
  return encoded;
}
