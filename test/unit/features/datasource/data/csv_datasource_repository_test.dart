import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/datasource/data/csv_datasource_repository.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late CsvDatasourceRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_csv_datasource_test_',
    );
    repository = const CsvDatasourceRepository();
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('carga CSV válido con encabezados, conteo y vista previa', () async {
    final filePath = p.join(tempDirectory.path, 'clientes.csv');
    await _writeCsv(
      filePath,
      'nombre,edad,ciudad\nAna,30,Bogotá\nLuis,25,Medellín\n',
    );

    final datasource = await repository.load(filePath);

    expect(datasource.fileName, 'clientes.csv');
    expect(datasource.format, DatasourceFormat.csv);
    expect(datasource.headers, <String>['nombre', 'edad', 'ciudad']);
    expect(datasource.previewRow, <String?>['Ana', '30', 'Bogotá']);
    expect(datasource.rowCount, 2);
    expect(datasource.emptyColumnIndexes, isEmpty);
  });

  test('parsea campos entrecomillados con comas y saltos de línea', () async {
    final filePath = p.join(tempDirectory.path, 'quoted.csv');
    await _writeCsv(
      filePath,
      'titulo,descripcion\n'
      '"Hola, mundo","Línea 1\nLínea 2"\n',
    );

    final datasource = await repository.load(filePath);

    expect(datasource.headers, <String>['titulo', 'descripcion']);
    expect(datasource.previewRow, <String?>['Hola, mundo', 'Línea 1\nLínea 2']);
    expect(datasource.rowCount, 1);
  });

  test('lanza FormatException cuando hay encabezados duplicados', () async {
    final filePath = p.join(tempDirectory.path, 'duplicados.csv');
    await _writeCsv(
      filePath,
      'nombre,nombre,correo\nAna,Ana,ana@example.com\n',
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

  test('lanza FormatException cuando el archivo está vacío', () async {
    final filePath = p.join(tempDirectory.path, 'vacio.csv');
    await _writeCsv(filePath, '');

    expect(
      () => repository.load(filePath),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('vacío'),
        ),
      ),
    );
  });

  test('archivo con solo encabezado es válido y rowCount es cero', () async {
    final filePath = p.join(tempDirectory.path, 'solo_encabezado.csv');
    await _writeCsv(filePath, 'nombre,correo\n');

    final datasource = await repository.load(filePath);

    expect(datasource.headers, <String>['nombre', 'correo']);
    expect(datasource.previewRow, <String?>[null, null]);
    expect(datasource.rowCount, 0);
  });

  test('detecta columnas completamente vacías', () async {
    final filePath = p.join(tempDirectory.path, 'columnas_vacias.csv');
    await _writeCsv(filePath, 'a,b,c\n1,,\n2,,\n');

    final datasource = await repository.load(filePath);

    expect(datasource.emptyColumnIndexes, <int>[1, 2]);
  });

  test('celdas vacías o faltantes en preview se convierten a null', () async {
    final filePath = p.join(tempDirectory.path, 'faltantes.csv');
    await _writeCsv(filePath, 'a,b,c\n1,,\n');

    final datasource = await repository.load(filePath);

    expect(datasource.previewRow, <String?>['1', null, null]);
  });

  test('rechaza extensiones distintas a .csv antes de leer', () async {
    final filePath = p.join(tempDirectory.path, 'datos.txt');

    expect(
      () => repository.load(filePath),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('.csv'),
        ),
      ),
    );
  });
}

Future<void> _writeCsv(String path, String content) async {
  await File(path).writeAsString(content);
}
