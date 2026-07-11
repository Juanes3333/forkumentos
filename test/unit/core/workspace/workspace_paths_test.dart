import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/workspace/workspace_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late WorkspacePaths paths;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_workspace_paths_',
    );
    paths = WorkspacePaths(root: tempDirectory.path);
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('ensureAll crea el árbol de carpetas', () async {
    await paths.ensureAll();

    for (final folder in <String>[
      paths.root,
      paths.projects,
      paths.exports,
      paths.workspace,
      paths.cache,
      paths.logs,
    ]) {
      expect(Directory(folder).existsSync(), isTrue);
    }
  });

  test('defaultProjectFile usa extensión .fork', () {
    expect(
      paths.defaultProjectFile('Demo'),
      p.join(paths.projects, 'Demo.fork'),
    );
  });

  test('nextAutomaticProjectName evita colisiones', () async {
    await Directory(paths.projects).create(recursive: true);
    await File(paths.defaultProjectFile('Proyecto 1')).writeAsString('x');
    await File(paths.defaultProjectFile('Proyecto 2')).writeAsString('x');

    final next = await paths.nextAutomaticProjectName();
    expect(next, 'Proyecto 3');
  });

  test('projectCache y exportFolder resuelven bajo root', () {
    expect(paths.projectCache('abc'), p.join(paths.cache, 'abc'));
    expect(
      paths.exportFolder('Mi Proyecto'),
      p.join(paths.exports, 'Mi Proyecto'),
    );
  });
}
