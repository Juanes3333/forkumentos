import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/datasource/data/xlsx_datasource_repository.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late XlsxDatasourceRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_xlsx_datasource_test_',
    );
    repository = const XlsxDatasourceRepository();
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('carga XLSX válido con encabezados, conteo y vista previa', () async {
    final filePath = p.join(tempDirectory.path, 'clientes.xlsx');
    await _writeWorkbook(
      path: filePath,
      rows: <List<CellValue?>>[
        <CellValue?>[
          TextCellValue('nombre'),
          TextCellValue('edad'),
          TextCellValue('ciudad'),
        ],
        <CellValue?>[
          TextCellValue('Ana'),
          TextCellValue('30'),
          TextCellValue('Bogotá'),
        ],
        <CellValue?>[
          TextCellValue('Luis'),
          TextCellValue('25'),
          TextCellValue('Medellín'),
        ],
      ],
    );

    final datasource = await repository.load(filePath);

    expect(datasource.fileName, 'clientes.xlsx');
    expect(datasource.format, DatasourceFormat.xlsx);
    expect(datasource.headers, <String>['nombre', 'edad', 'ciudad']);
    expect(datasource.previewRow, <String?>['Ana', '30', 'Bogotá']);
    expect(datasource.rowCount, 2);
    expect(datasource.emptyColumnIndexes, isEmpty);
  });

  test('usa la primera hoja del libro', () async {
    final filePath = p.join(tempDirectory.path, 'multiples_hojas.xlsx');
    await _writeWorkbook(
      path: filePath,
      rows: <List<CellValue?>>[
        <CellValue?>[TextCellValue('primera_columna')],
        <CellValue?>[TextCellValue('valor_primera_hoja')],
      ],
      secondSheetRows: <List<CellValue?>>[
        <CellValue?>[TextCellValue('segunda_columna')],
        <CellValue?>[TextCellValue('valor_segunda_hoja')],
      ],
    );

    final datasource = await repository.load(filePath);

    expect(datasource.headers, <String>['primera_columna']);
    expect(datasource.previewRow, <String?>['valor_primera_hoja']);
  });

  test('mantiene comas y saltos de línea en celdas de texto', () async {
    final filePath = p.join(tempDirectory.path, 'texto_complejo.xlsx');
    await _writeWorkbook(
      path: filePath,
      rows: <List<CellValue?>>[
        <CellValue?>[TextCellValue('titulo'), TextCellValue('descripcion')],
        <CellValue?>[
          TextCellValue('Hola, mundo'),
          TextCellValue('Línea 1\nLínea 2'),
        ],
      ],
    );

    final datasource = await repository.load(filePath);

    expect(datasource.previewRow, <String?>['Hola, mundo', 'Línea 1\nLínea 2']);
  });

  test('lanza FormatException cuando hay encabezados duplicados', () async {
    final filePath = p.join(tempDirectory.path, 'duplicados.xlsx');
    await _writeWorkbook(
      path: filePath,
      rows: <List<CellValue?>>[
        <CellValue?>[TextCellValue('nombre'), TextCellValue('nombre')],
        <CellValue?>[TextCellValue('Ana'), TextCellValue('Ana')],
      ],
    );

    expect(
      () => repository.load(filePath),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('encabezados duplicados'),
        ),
      ),
    );
  });

  test('lanza FormatException cuando no hay encabezados', () async {
    final filePath = p.join(tempDirectory.path, 'sin_encabezados.xlsx');
    await _writeWorkbook(path: filePath, rows: const <List<CellValue?>>[]);

    expect(
      () => repository.load(filePath),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('encabezados'),
        ),
      ),
    );
  });

  test('archivo con solo encabezado es válido y rowCount es cero', () async {
    final filePath = p.join(tempDirectory.path, 'solo_encabezado.xlsx');
    await _writeWorkbook(
      path: filePath,
      rows: <List<CellValue?>>[
        <CellValue?>[TextCellValue('nombre'), TextCellValue('correo')],
      ],
    );

    final datasource = await repository.load(filePath);

    expect(datasource.headers, <String>['nombre', 'correo']);
    expect(datasource.previewRow, <String?>[null, null]);
    expect(datasource.rowCount, 0);
  });

  test('detecta columnas completamente vacías', () async {
    final filePath = p.join(tempDirectory.path, 'columnas_vacias.xlsx');
    await _writeWorkbook(
      path: filePath,
      rows: <List<CellValue?>>[
        <CellValue?>[
          TextCellValue('a'),
          TextCellValue('b'),
          TextCellValue('c'),
        ],
        <CellValue?>[TextCellValue('1'), null, null],
        <CellValue?>[TextCellValue('2'), null, null],
      ],
    );

    final datasource = await repository.load(filePath);

    expect(datasource.emptyColumnIndexes, <int>[1, 2]);
  });

  test('celdas vacías o faltantes en preview se convierten a null', () async {
    final filePath = p.join(tempDirectory.path, 'faltantes.xlsx');
    await _writeWorkbook(
      path: filePath,
      rows: <List<CellValue?>>[
        <CellValue?>[
          TextCellValue('a'),
          TextCellValue('b'),
          TextCellValue('c'),
        ],
        <CellValue?>[TextCellValue('1'), null],
      ],
    );

    final datasource = await repository.load(filePath);

    expect(datasource.previewRow, <String?>['1', null, null]);
  });

  test('lanza FormatException con bytes XLSX corruptos', () async {
    final filePath = p.join(tempDirectory.path, 'corrupto.xlsx');
    await File(filePath).writeAsBytes(<int>[0, 1, 2, 3, 4, 5, 6]);

    expect(() => repository.load(filePath), throwsA(isA<FormatException>()));
  });

  test('rechaza extensiones distintas a .xlsx antes de leer', () async {
    final filePath = p.join(tempDirectory.path, 'datos.csv');

    expect(
      () => repository.load(filePath),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('.xlsx'),
        ),
      ),
    );
  });
}

Future<void> _writeWorkbook({
  required String path,
  required List<List<CellValue?>> rows,
  List<List<CellValue?>>? secondSheetRows,
}) async {
  final excel = Excel.createExcel()..rename('Sheet1', 'Primera');
  final firstSheet = excel['Primera'];
  for (final row in rows) {
    firstSheet.appendRow(row);
  }

  final otherRows = secondSheetRows;
  if (otherRows != null) {
    final secondSheet = excel['Segunda'];
    for (final row in otherRows) {
      secondSheet.appendRow(row);
    }
  }

  final encoded = excel.encode();
  if (encoded == null) {
    throw StateError('No se pudo codificar el workbook de prueba.');
  }
  await File(path).writeAsBytes(Uint8List.fromList(encoded));
}
