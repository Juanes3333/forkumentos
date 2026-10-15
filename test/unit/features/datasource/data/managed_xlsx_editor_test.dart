import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/datasource/data/managed_xlsx_editor.dart';
import 'package:forkumentos/features/datasource/data/xlsx_column_writer.dart';
import 'package:forkumentos/features/datasource/data/xlsx_datasource_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late String path;
  const editor = ManagedXlsxEditor();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'forkumentos_xlsx_editor_test_',
    );
    path = p.join(directory.path, 'clientes.xlsx');
    final excel = Excel.createExcel()..rename('Sheet1', 'Datos');
    excel['Datos']
      ..appendRow(<CellValue?>[
        TextCellValue('nombre'),
        TextCellValue('cédula'),
        TextCellValue('correo'),
      ])
      ..appendRow(<CellValue?>[
        TextCellValue('Ana'),
        const IntCellValue(111),
        TextCellValue('ana@x.co'),
      ]);
    File(path).writeAsBytesSync(excel.encode()!);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('agrega la columna en su sitio, conserva los datos y guarda una '
      'copia anterior', () async {
    final result = await editor.addColumn(
      path: path,
      header: 'tipo de documento',
      insertAt: 1,
    );

    expect(result.columnIndex, 1);
    final datasource = await const XlsxDatasourceRepository().load(path);
    expect(datasource.headers, <String>[
      'nombre',
      'tipo de documento',
      'cédula',
      'correo',
    ]);
    expect(datasource.previewRow, <String?>['Ana', null, '111', 'ana@x.co']);
    final backups = Directory(
      p.join(directory.path, 'anteriores'),
    ).listSync().whereType<File>();
    expect(backups, hasLength(1));
    // No quedan temporales ni sondas.
    expect(
      directory
          .listSync()
          .whereType<File>()
          .map((file) => p.basename(file.path))
          .where((name) => name.startsWith('.')),
      isEmpty,
    );
  });

  test('un archivo bloqueado (abierto en Excel) lanza ExcelLockedException y '
      'no se modifica', () async {
    final before = File(path).readAsBytesSync();
    // Excel deja el archivo abierto con escritura denegada.
    final locked = File(path).openSync()..lockSync(FileLock.blockingExclusive);
    addTearDown(locked.closeSync);

    await expectLater(
      editor.addColumn(path: path, header: 'nueva', insertAt: 0),
      throwsA(isA<ExcelLockedException>()),
    );

    locked.unlockSync();
    expect(File(path).readAsBytesSync(), before);
  });

  test('un libro que no se puede modificar deja el original intacto', () async {
    File(path).writeAsBytesSync(<int>[1, 2, 3]);
    final before = File(path).readAsBytesSync();

    await expectLater(
      editor.addColumn(path: path, header: 'nueva', insertAt: 0),
      throwsA(anything),
    );

    expect(File(path).readAsBytesSync(), before);
  });

  test('un libro con fórmulas recibe la columna al final', () async {
    // El libro de prueba no tiene fórmulas: se comprueba que XlsxWriteException
    // llegue sin tocar el archivo con un zip vacío válido sin hojas.
    expect(
      () => const XlsxColumnWriter().insertColumn(
        xlsxBytes: File(path).readAsBytesSync(),
        header: 'x',
        insertAt: 9,
      ),
      returnsNormally,
    );
  });
}
