import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/export/data/docx_export_command.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_docx_export_cancel_test_',
    );
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('cancela a mitad de exportación y marca skipped', () async {
    final template = _buildDocxBytes(
      documentXml: _documentWithBody(
        '<w:p><w:r><w:t>Hola Ana</w:t></w:r></w:p>',
      ),
    );

    final rows = <int, List<String?>>{
      0: const <String?>['A'],
      1: const <String?>['B'],
      2: const <String?>['C'],
      3: const <String?>['D'],
    };

    late final DocxExportCommand command;
    command = DocxExportCommand(
      templateBytes: template,
      destinationFolder: tempDirectory.path,
      filenamePattern: const FilenamePattern(
        blocks: <FilenamePatternBlock>[FilenameTextBlock('doc')],
      ),
      rowIndexes: const <int>[0, 1, 2, 3],
      placeholders: const <ExportPlaceholder>[
        ExportPlaceholder(
          pageIndex: 0,
          steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
          startOffset: 5,
          endOffset: 8,
          fieldIndex: 0,
        ),
      ],
      headers: const <String>['nombre'],
      resolveRow: (rowIndex) async {
        if (rowIndex == 1) {
          command.cancel();
        }
        return rows[rowIndex]!;
      },
    );

    final result = await command.execute();

    expect(result.cancelled, isTrue);
    expect(result.exportedCount, lessThan(4));
    expect(result.skippedCount, greaterThan(0));
    expect(result.exportedCount + result.failedCount + result.skippedCount, 4);
  });

  test('exporta al menos 3 filas a archivos DOCX distintos', () async {
    final template = _buildDocxBytes(
      documentXml: _documentWithBody(
        '<w:p><w:r><w:t>Hola Ana</w:t></w:r></w:p>',
      ),
    );

    final rows = <int, List<String?>>{
      0: const <String?>['Ana'],
      1: const <String?>['Luis'],
      2: const <String?>['Eva'],
    };

    final command = DocxExportCommand(
      templateBytes: template,
      destinationFolder: tempDirectory.path,
      filenamePattern: const FilenamePattern(
        blocks: <FilenamePatternBlock>[
          FilenameFieldBlock(fieldIndex: 0, fieldHeader: 'nombre'),
        ],
      ),
      rowIndexes: const <int>[0, 1, 2],
      placeholders: const <ExportPlaceholder>[
        ExportPlaceholder(
          pageIndex: 0,
          steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
          startOffset: 5,
          endOffset: 8,
          fieldIndex: 0,
        ),
      ],
      headers: const <String>['nombre'],
      resolveRow: (rowIndex) async => rows[rowIndex]!,
    );

    final result = await command.execute();

    expect(result.exportedCount, 3);
    expect(result.writtenFiles, hasLength(3));
    expect(result.writtenFiles.toSet(), hasLength(3));
    for (final path in result.writtenFiles) {
      expect(File(path).existsSync(), isTrue);
      expect(File(path).lengthSync(), greaterThan(0));
    }

    final texts = result.writtenFiles.map((path) {
      final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
      final document = archive.files.firstWhere(
        (file) => file.name.toLowerCase() == 'word/document.xml',
      );
      return utf8.decode(document.content as List<int>);
    }).toList();

    expect(texts[0], contains('Ana'));
    expect(texts[1], contains('Luis'));
    expect(texts[2], contains('Eva'));
  });
}

Uint8List _buildDocxBytes({required String documentXml}) {
  final archive = Archive()
    ..addFile(
      ArchiveFile(
        'word/document.xml',
        utf8.encode(documentXml).length,
        utf8.encode(documentXml),
      ),
    )
    ..addFile(
      ArchiveFile(
        '[Content_Types].xml',
        utf8.encode('<Types/>').length,
        utf8.encode('<Types/>'),
      ),
    );

  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('No se pudo codificar DOCX de prueba.');
  }
  return Uint8List.fromList(encoded);
}

String _documentWithBody(String bodyInner) {
  return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>$bodyInner</w:body>
</w:document>
''';
}
