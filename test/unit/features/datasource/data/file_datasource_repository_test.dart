import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/datasource/data/file_datasource_repository.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late FileDatasourceRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_file_datasource_test_',
    );
    repository = const FileDatasourceRepository();
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('despacha a CSV según extensión', () async {
    final filePath = p.join(tempDirectory.path, 'clientes.CSV');
    await File(filePath).writeAsString('nombre,edad\nAna,30\n');

    final datasource = await repository.load(filePath);

    expect(datasource.format, DatasourceFormat.csv);
    expect(datasource.headers, <String>['nombre', 'edad']);
    expect(datasource.rowCount, 1);
  });

  test('despacha a XLSX según extensión', () async {
    final filePath = p.join(tempDirectory.path, 'clientes.XLSX');
    final excel = Excel.createExcel()..rename('Sheet1', 'Datos');
    excel['Datos']
      ..appendRow(<CellValue?>[TextCellValue('nombre')])
      ..appendRow(<CellValue?>[TextCellValue('Ana')]);
    await File(filePath).writeAsBytes(excel.encode()!);

    final datasource = await repository.load(filePath);

    expect(datasource.format, DatasourceFormat.xlsx);
    expect(datasource.headers, <String>['nombre']);
    expect(datasource.rowCount, 1);
  });

  test('rechaza extensiones no soportadas', () async {
    final filePath = p.join(tempDirectory.path, 'clientes.json');

    expect(
      () => repository.load(filePath),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('.csv o .xlsx'),
        ),
      ),
    );
  });
}
