import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/datasource/data/xlsx_column_writer.dart';
import 'package:forkumentos/features/datasource/data/xlsx_datasource_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  const writer = XlsxColumnWriter();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'forkumentos_xlsx_writer_test_',
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  /// Libro mÃ­nimo con estilos en los encabezados, anchos de columna, una celda
  /// combinada, una validaciÃ³n de datos y, opcionalmente, una fÃ³rmula o una
  /// tabla. Columnas: nombre | cÃ©dula | correo.
  Uint8List workbook({bool formula = false, bool table = false}) {
    final sheet =
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<dimension ref="A1:C3"/>
<cols><col min="1" max="1" width="20" customWidth="1"/><col min="2" max="2" width="12" customWidth="1"/><col min="3" max="3" width="30" customWidth="1"/></cols>
<sheetData>
<row r="1" spans="1:3"><c r="A1" s="1" t="inlineStr"><is><t>nombre</t></is></c><c r="B1" s="1" t="inlineStr"><is><t>cÃ©dula</t></is></c><c r="C1" s="1" t="inlineStr"><is><t>correo</t></is></c></row>
<row r="2" spans="1:3"><c r="A2" t="inlineStr"><is><t>Ana</t></is></c><c r="B2"><v>111</v></c><c r="C2" t="inlineStr"><is><t>ana@x.co</t></is></c></row>
<row r="3" spans="1:3"><c r="A3" t="inlineStr"><is><t>Luis</t></is></c><c r="B3"><v>222</v></c>${formula ? '<c r="C3"><f>B3*2</f><v>444</v></c>' : '<c r="C3" t="inlineStr"><is><t>luis@x.co</t></is></c>'}</row>
</sheetData>
<mergeCells count="1"><mergeCell ref="A5:B5"/></mergeCells>
<dataValidations count="1"><dataValidation type="list" sqref="C2:C3"><formula1>"a,b"</formula1></dataValidation></dataValidations>
${table ? '<tableParts count="1"><tablePart r:id="rId1" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/></tableParts>' : ''}
</worksheet>
''';
    final archive = Archive()
      ..addFile(_file('[Content_Types].xml', _contentTypes))
      ..addFile(_file('_rels/.rels', _rootRels))
      ..addFile(_file('xl/workbook.xml', _workbookXml))
      ..addFile(_file('xl/_rels/workbook.xml.rels', _workbookRels))
      ..addFile(_file('xl/styles.xml', _styles))
      ..addFile(_file('xl/worksheets/sheet1.xml', sheet));
    if (table) {
      archive.addFile(
        _file(
          'xl/tables/table1.xml',
          '<table xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" id="1" name="T" ref="A1:C3"/>',
        ),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  String sheetXml(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    return utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
    );
  }

  Future<({List<String> headers, int rows, List<String?> first})> reload(
    Uint8List bytes,
  ) async {
    final path = p.join(directory.path, 'salida.xlsx');
    File(path).writeAsBytesSync(bytes);
    final datasource = await const XlsxDatasourceRepository().load(path);
    return (
      headers: datasource.headers,
      rows: datasource.rowCount,
      first: datasource.previewRow,
    );
  }

  test('insertar en medio desplaza celdas, anchos, combinadas y validaciones '
      'y el libro sigue leyÃ©ndose', () async {
    final result = writer.insertColumn(
      xlsxBytes: workbook(),
      header: 'tipo de documento',
      insertAt: 1,
    );

    expect(result.columnIndex, 1);
    expect(result.appendedAtEnd, isFalse);
    final xml = sheetXml(result.bytes);
    // Celdas desplazadas: cÃ©dula pasÃ³ de B a C y correo de C a D.
    expect(xml, contains('r="C1"'));
    expect(xml, contains('r="D2"'));
    expect(xml, isNot(contains('r="C1" s="1" t="inlineStr"><is><t>correo')));
    // Encabezado nuevo en B1 con el estilo del vecino.
    expect(xml, contains('r="B1" s="1" t="inlineStr"'));
    // Anchos: la columna 2 y 3 pasan a 3 y 4.
    expect(xml, contains('min="3" max="3" width="12"'));
    expect(xml, contains('min="4" max="4" width="30"'));
    // Combinada B2:C2 -> C2:D2; validaciÃ³n C2:C3 -> D2:D3; dimensiÃ³n A1:D3.
    expect(xml, contains('mergeCell ref="A5:C5"'));
    expect(xml, contains('sqref="D2:D3"'));
    expect(xml, contains('dimension ref="A1:D3"'));

    final reread = await reload(result.bytes);
    expect(reread.headers, <String>[
      'nombre',
      'tipo de documento',
      'cÃ©dula',
      'correo',
    ]);
    expect(reread.rows, 2);
    expect(reread.first, <String?>['Ana', null, '111', 'ana@x.co']);
  });

  test('insertar al final no desplaza nada', () async {
    final result = writer.insertColumn(
      xlsxBytes: workbook(),
      header: 'telÃ©fono',
      insertAt: 3,
    );

    expect(result.columnIndex, 3);
    final reread = await reload(result.bytes);
    expect(reread.headers.last, 'telÃ©fono');
    expect(reread.first, <String?>['Ana', '111', 'ana@x.co', null]);
  });

  test('un libro con fÃ³rmulas recibe la columna al final para no romper '
      'referencias', () async {
    final result = writer.insertColumn(
      xlsxBytes: workbook(formula: true),
      header: 'tipo de documento',
      insertAt: 1,
    );

    expect(result.appendedAtEnd, isTrue);
    expect(result.columnIndex, 3);
    final xml = sheetXml(result.bytes);
    expect(xml, contains('<f>B3*2</f>'));
    expect(xml, contains('r="D1"'));
    final reread = await reload(result.bytes);
    expect(reread.headers, <String>[
      'nombre',
      'cÃ©dula',
      'correo',
      'tipo de documento',
    ]);
  });

  test('un libro con tablas recibe la columna al final', () async {
    final result = writer.insertColumn(
      xlsxBytes: workbook(table: true),
      header: 'nueva',
      insertAt: 0,
    );

    expect(result.appendedAtEnd, isTrue);
    expect(result.columnIndex, 3);
    final archive = ZipDecoder().decodeBytes(result.bytes);
    // La parte de la tabla sigue intacta.
    expect(archive.findFile('xl/tables/table1.xml'), isNotNull);
  });

  test('conserva las demÃ¡s partes del libro sin modificarlas', () async {
    final original = workbook();
    final result = writer.insertColumn(
      xlsxBytes: original,
      header: 'nueva',
      insertAt: 1,
    );

    final before = ZipDecoder().decodeBytes(original);
    final after = ZipDecoder().decodeBytes(result.bytes);
    for (final name in <String>[
      'xl/styles.xml',
      'xl/workbook.xml',
      '[Content_Types].xml',
    ]) {
      expect(
        after.findFile(name)!.content,
        before.findFile(name)!.content,
        reason: name,
      );
    }
  });

  test('un encabezado con espacios se conserva tal cual', () async {
    final result = writer.insertColumn(
      xlsxBytes: workbook(),
      header: ' con espacios ',
      insertAt: 3,
    );

    expect(sheetXml(result.bytes), contains('xml:space="preserve"'));
  });

  test('un archivo que no es XLSX lanza XlsxWriteException', () {
    expect(
      () => writer.insertColumn(
        xlsxBytes: utf8.encode('no soy un zip'),
        header: 'x',
        insertAt: 0,
      ),
      throwsA(isA<XlsxWriteException>()),
    );
  });
}

ArchiveFile _file(String name, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes);
}

final _contentTypes = <String>[
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
  '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
  '<Default Extension="xml" ContentType="application/xml"/>',
  '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
  '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
  '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
  '</Types>',
].join();

final _rootRels = <String>[
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>',
  '</Relationships>',
].join();

final _workbookXml = <String>[
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ',
  'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
  '<sheets><sheet name="Datos" sheetId="1" r:id="rId1"/></sheets></workbook>',
].join();

final _workbookRels = <String>[
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>',
  '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
  '</Relationships>',
].join();

final _styles = <String>[
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
  '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>',
  '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>',
  '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>',
  '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>',
  '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>',
  '</styleSheet>',
].join();
