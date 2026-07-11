import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/preview/data/preview_record_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late PreviewRecordRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_preview_record_test_',
    );
    repository = PreviewRecordRepository();
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('lee fila N de CSV', () async {
    final filePath = p.join(tempDirectory.path, 'datos.csv');
    await File(
      filePath,
    ).writeAsString('nombre,edad\nAna,30\nLuis,25\nEva,40\n');

    final datasource = _csvDatasource(filePath, rowCount: 3);
    final row = await repository.readRecord(
      datasource: datasource,
      rowIndex: 2,
    );

    expect(row, <String?>['Eva', '40']);
  });

  test('resuelve varias filas CSV en un solo barrido', () async {
    final filePath = p.join(tempDirectory.path, 'batch.csv');
    await File(
      filePath,
    ).writeAsString('nombre,edad\nA,1\nB,2\nC,3\nD,4\nE,5\n');

    final datasource = _csvDatasource(filePath, rowCount: 5);
    final rows = await repository.readRecords(
      datasource: datasource,
      rowIndexes: const <int>[4, 1, 3],
    );

    expect(rows[1], <String?>['B', '2']);
    expect(rows[3], <String?>['D', '4']);
    expect(rows[4], <String?>['E', '5']);
  });

  test('lee fila N de XLSX y no re-decodifica con la misma ruta', () async {
    final filePath = p.join(tempDirectory.path, 'datos.xlsx');
    await _writeWorkbook(
      path: filePath,
      rows: <List<CellValue?>>[
        <CellValue?>[TextCellValue('nombre'), TextCellValue('edad')],
        <CellValue?>[TextCellValue('Ana'), const IntCellValue(30)],
        <CellValue?>[TextCellValue('Luis'), const IntCellValue(25)],
        <CellValue?>[TextCellValue('Eva'), const IntCellValue(40)],
      ],
    );

    final datasource = Datasource(
      sourcePath: filePath,
      fileName: 'datos.xlsx',
      fileSizeBytes: File(filePath).lengthSync(),
      importedAt: DateTime.utc(2026),
      format: DatasourceFormat.xlsx,
      headers: const <String>['nombre', 'edad'],
      previewRow: const <String?>['Ana', '30'],
      rowCount: 3,
      emptyColumnIndexes: const <int>[],
    );

    final first = await repository.readRecord(
      datasource: datasource,
      rowIndex: 2,
    );
    expect(first, <String?>['Eva', '40']);
    expect(repository.xlsxDecodeCount, 1);

    final second = await repository.readRecord(
      datasource: datasource,
      rowIndex: 0,
    );
    expect(second, <String?>['Ana', '30']);
    expect(repository.xlsxDecodeCount, 1);

    final batch = await repository.readRecords(
      datasource: datasource,
      rowIndexes: const <int>[1, 2],
    );
    expect(batch[1], <String?>['Luis', '25']);
    expect(repository.xlsxDecodeCount, 1);
  });
}

Datasource _csvDatasource(String filePath, {required int rowCount}) {
  return Datasource(
    sourcePath: filePath,
    fileName: p.basename(filePath),
    fileSizeBytes: File(filePath).lengthSync(),
    importedAt: DateTime.utc(2026),
    format: DatasourceFormat.csv,
    headers: const <String>['nombre', 'edad'],
    previewRow: const <String?>['Ana', '30'],
    rowCount: rowCount,
    emptyColumnIndexes: const <int>[],
  );
}

Future<void> _writeWorkbook({
  required String path,
  required List<List<CellValue?>> rows,
}) async {
  final excel = Excel.createExcel()..rename('Sheet1', 'Datos');
  final sheet = excel['Datos'];
  for (final row in rows) {
    sheet.appendRow(row);
  }

  final encoded = excel.encode();
  if (encoded == null) {
    throw StateError('No se pudo codificar el workbook de prueba.');
  }
  await File(path).writeAsBytes(Uint8List.fromList(encoded));
}
