import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/workspace/workspace_paths.dart';
import 'package:forkumentos/features/datasource/data/managed_datasource_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late String folder;
  const store = ManagedDatasourceStore(keepBackups: 2);

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_managed_store_test_',
    );
    folder = p.join(tempDirectory.path, 'Workspace', 'Proyecto-abc12345');
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  File source(String name, String content) =>
      File(p.join(tempDirectory.path, 'original', name))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  test('copia el archivo a la carpeta gestionada y deja el original', () async {
    final original = source('clientes.csv', 'nombre\nAna\n');

    final managed = await store.adopt(
      sourcePath: original.path,
      folder: folder,
    );

    expect(managed, p.join(folder, 'clientes.csv'));
    expect(File(managed).readAsStringSync(), 'nombre\nAna\n');
    expect(original.existsSync(), isTrue);
    expect(store.isManaged(managed, folder), isTrue);
    expect(store.isManaged(original.path, folder), isFalse);
  });

  test('un archivo que ya es el gestionado no se toca', () async {
    final original = source('clientes.csv', 'v1');
    final managed = await store.adopt(
      sourcePath: original.path,
      folder: folder,
    );

    final again = await store.adopt(sourcePath: managed, folder: folder);

    expect(again, managed);
    expect(Directory(p.join(folder, 'anteriores')).existsSync(), isFalse);
  });

  test('reemplazar guarda la versión anterior en anteriores/', () async {
    await store.adopt(
      sourcePath: source('clientes.csv', 'v1').path,
      folder: folder,
    );

    await store.adopt(
      sourcePath: source('clientes.csv', 'v2').path,
      folder: folder,
    );

    expect(File(p.join(folder, 'clientes.csv')).readAsStringSync(), 'v2');
    final backups = Directory(
      p.join(folder, 'anteriores'),
    ).listSync().whereType<File>().toList();
    expect(backups, hasLength(1));
    expect(backups.single.readAsStringSync(), 'v1');
    expect(p.basename(backups.single.path), endsWith('_clientes.csv'));
  });

  test('solo conserva las últimas versiones anteriores', () async {
    for (var version = 1; version <= 5; version++) {
      await store.adopt(
        sourcePath: source('clientes.csv', 'v$version').path,
        folder: folder,
      );
      // Los nombres llevan milisegundos: se separa para que sean distintos.
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    final backups =
        Directory(p.join(folder, 'anteriores'))
            .listSync()
            .whereType<File>()
            .map((file) => file.readAsStringSync())
            .toList()
          ..sort();
    // Cuatro reemplazos hicieron cuatro copias; quedan las dos más nuevas.
    expect(backups, <String>['v3', 'v4']);
  });

  test('un origen inexistente lanza FileSystemException', () async {
    await expectLater(
      store.adopt(
        sourcePath: p.join(tempDirectory.path, 'no_existe.csv'),
        folder: folder,
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  group('WorkspacePaths.managedDatasourceFolder', () {
    final paths = WorkspacePaths(root: p.join('C:', 'Forkumentos'));

    test('lleva el nombre del proyecto y el id corto', () {
      expect(
        paths.managedDatasourceFolder(
          projectName: 'Contrato Ana',
          projectId: '123e4567-e89b-12d3',
        ),
        p.join(paths.workspace, 'Contrato Ana-123e4567'),
      );
    });

    test('dos proyectos con el mismo nombre no comparten carpeta', () {
      expect(
        paths.managedDatasourceFolder(projectName: 'X', projectId: 'aaaaaaaa1'),
        isNot(
          paths.managedDatasourceFolder(
            projectName: 'X',
            projectId: 'bbbbbbbb2',
          ),
        ),
      );
    });

    test('sanea caracteres no válidos en nombres de carpeta', () {
      final folder = paths.managedDatasourceFolder(
        projectName: 'A/B:C*',
        projectId: 'abcdef012',
      );

      expect(p.basename(folder), 'A_B_C_-abcdef01');
    });
  });
}
