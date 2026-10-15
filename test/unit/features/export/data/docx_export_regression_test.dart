import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/export/data/docx_export_command.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';

/// Candado de regresión del exportador: un documento con texto repartido en
/// varios runs con formato, una celda de tabla, una lista numerada, un rango
/// entre párrafos y un encabezado intacto. Compara el `word/document.xml` y
/// el `word/header1.xml` completos (no los bytes del zip, que cambian entre
/// ejecuciones). Si este test falla, cambió el resultado del export: revisa
/// antes de actualizar el esperado (ver docx-parity-check).
void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_docx_export_regression_',
    );
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  const headers = <String>['nombre', 'cedula', 'items', 'cuerpo'];
  final rows = <int, List<String?>>{
    0: const <String?>['Ana Pérez', '123', 'Uno\nDos', 'Línea A.\nLínea B.'],
    1: const <String?>['Luis Gómez', '456', 'Tres', 'Solo una.'],
    2: const <String?>['Eva Ríos', null, 'Cuatro\nCinco\nSeis', 'X.\nY.\nZ.'],
  };

  const placeholders = <ExportPlaceholder>[
    // "NOMBRE" (offsets 9..15) en el bloque 0, repartido en tres runs.
    ExportPlaceholder(
      steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
      startOffset: 9,
      endOffset: 15,
      fieldIndex: 0,
    ),
    // "CED" en la celda (fila 0, celda 0, bloque 0) de la tabla (bloque 1).
    ExportPlaceholder(
      steps: <ExportPathStep>[
        ExportPathStep.rootBlock(blockIndex: 1),
        ExportPathStep.cellBlock(rowIndex: 0, cellIndex: 0, blockIndex: 0),
      ],
      startOffset: 0,
      endOffset: 3,
      fieldIndex: 1,
    ),
    // Lista numerada que empieza en el bloque 2.
    ExportPlaceholder(
      steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 2)],
      startOffset: 0,
      endOffset: 0,
      fieldIndex: 2,
      isListField: true,
    ),
    // Rango entre los bloques 5 y 6.
    ExportPlaceholder(
      steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 5)],
      startOffset: 10,
      endOffset: 0,
      fieldIndex: 3,
      endBlockIndex: 6,
    ),
  ];

  Future<List<String>> exportAndReadParts() async {
    final command = DocxExportCommand(
      templateBytes: _template(),
      destinationFolder: tempDirectory.path,
      filenamePattern: const FilenamePattern(
        blocks: <FilenamePatternBlock>[
          FilenameFieldBlock(fieldIndex: 0, fieldHeader: 'nombre'),
        ],
      ),
      rowIndexes: const <int>[0, 1, 2],
      placeholders: placeholders,
      headers: headers,
      templateBaseName: 'plantilla',
      resolveRow: (rowIndex) async => rows[rowIndex]!,
    );
    final result = await command.execute();
    expect(result.exportedCount, 3);
    expect(result.failedCount, 0);

    final parts = <String>[];
    for (final path in result.writtenFiles) {
      final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
      for (final name in const <String>[
        'word/document.xml',
        'word/header1.xml',
      ]) {
        final file = archive.files.firstWhere((f) => f.name == name);
        parts.add(utf8.decode(file.content as List<int>));
      }
    }
    return parts;
  }

  test('el documento exportado conserva exactamente su estructura y '
      'formato por fila', () async {
    final parts = await exportAndReadParts();

    // Por fila: [document.xml, header1.xml].
    expect(parts, hasLength(6));
    final expected = <String>[
      _expectedDocument(
        name: 'Ana Pérez',
        cedula: '123',
        items: <String>['Uno', 'Dos'],
        rangeParagraphs: <String>['Atención: Línea A.', 'Línea B.Cierre.'],
      ),
      // Una sola línea en la lista y en el rango: la lista se contrae y el
      // rango se funde con el sufijo del párrafo final.
      _expectedDocument(
        name: 'Luis Gómez',
        cedula: '456',
        items: <String>['Tres'],
        rangeParagraphs: <String>['Atención: Solo una.Cierre.'],
      ),
      // Dato nulo: la celda queda vacía; la lista y el rango se expanden.
      _expectedDocument(
        name: 'Eva Ríos',
        cedula: '',
        items: <String>['Cuatro', 'Cinco', 'Seis'],
        rangeParagraphs: <String>['Atención: X.', 'Y.', 'Z.Cierre.'],
      ),
    ];
    for (var row = 0; row < 3; row++) {
      expect(
        _compact(parts[row * 2]),
        expected[row],
        reason: 'document.xml de la fila $row',
      );
      expect(
        parts[row * 2 + 1],
        _header,
        reason: 'header1.xml debe quedar intacto en la fila $row',
      );
    }
  });
}

const String _header = '<w:hdr>HEADER_INTACT</w:hdr>';

String _compact(String xml) => xml.replaceAll(RegExp(r'\s*\n\s*'), '');

Uint8List _template() {
  const documentXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">Estimado </w:t></w:r>
      <w:r><w:rPr><w:i/></w:rPr><w:t>NOM</w:t></w:r>
      <w:r><w:t>BRE, bienvenido.</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>CED</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
    <w:p>
      <w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>
      <w:r><w:t>Item uno</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>
      <w:r><w:t>Item dos</w:t></w:r>
    </w:p>
    <w:p><w:r><w:t>Separador.</w:t></w:r></w:p>
    <w:p><w:r><w:t>Atención: </w:t></w:r></w:p>
    <w:p><w:r><w:t>Cierre.</w:t></w:r></w:p>
  </w:body>
</w:document>
''';
  final archive = Archive()
    ..addFile(_file('word/document.xml', documentXml))
    ..addFile(_file('word/header1.xml', _header))
    ..addFile(_file('[Content_Types].xml', '<Types/>'));
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('No se pudo codificar el DOCX de prueba.');
  }
  return Uint8List.fromList(encoded);
}

ArchiveFile _file(String name, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes);
}

/// Documento esperado, compactado. El nombre hereda el formato (cursiva) del
/// run donde empieza el reemplazo; el resto de runs conserva texto y formato.
String _expectedDocument({
  required String name,
  required String cedula,
  required List<String> items,
  required List<String> rangeParagraphs,
}) {
  final cell = cedula.isEmpty ? '<w:t/>' : '<w:t>$cedula</w:t>';
  final list = items
      .map(
        (item) => <String>[
          '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/>',
          '</w:numPr></w:pPr><w:r><w:t>$item</w:t></w:r></w:p>',
        ].join(),
      )
      .join();
  final range = rangeParagraphs
      .map((text) => '<w:p><w:r><w:t>$text</w:t></w:r></w:p>')
      .join();
  return <String>[
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<w:document xmlns:w="http://schemas.openxmlformats.org/',
    'wordprocessingml/2006/main"><w:body>',
    '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">Estimado ',
    '</w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t>$name</w:t></w:r>',
    '<w:r><w:t>, bienvenido.</w:t></w:r></w:p>',
    '<w:tbl><w:tr><w:tc><w:p><w:r>$cell</w:r></w:p></w:tc></w:tr></w:tbl>',
    list,
    '<w:p><w:r><w:t>Separador.</w:t></w:r></w:p>',
    range,
    '</w:body></w:document>',
  ].join();
}
