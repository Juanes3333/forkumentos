import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/project/data/local_project_repository.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late LocalProjectRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_project_repo_test_',
    );
    repository = const LocalProjectRepository();
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('save y load round-trip ZIP con artefactos embebidos', () async {
    final templateSource = File(p.join(tempDirectory.path, 'plantilla.docx'))
      ..writeAsBytesSync(utf8.encode('DOCX-BYTES'));
    final datasourceSource = File(p.join(tempDirectory.path, 'datos.csv'))
      ..writeAsStringSync('nombre,correo\nAna,a@x.com\n');

    final sourceProject = Project(
      id: 'project-1',
      name: 'Proyecto Persistente',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 1, 2),
      mappingAssignments: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'assignment-1', 'fieldIndex': 0},
      ],
    );
    final filePath = p.join(tempDirectory.path, 'proyecto_persistente.fork');
    final cacheRoot = p.join(tempDirectory.path, 'Cache');

    final savedProject = await repository.save(
      project: sourceProject,
      filePath: filePath,
      templateSourcePath: templateSource.path,
      datasourceSourcePath: datasourceSource.path,
      cacheDirectory: cacheRoot,
    );
    expect(savedProject.filePath, filePath);
    expect(savedProject.embeddedTemplatePath, isNotNull);
    expect(savedProject.embeddedDatasourcePath, isNotNull);

    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.findFile('manifest.json'), isNotNull);
    expect(archive.findFile('project.json'), isNotNull);
    expect(archive.findFile('mappings.json'), isNotNull);
    expect(archive.findFile('template/plantilla.docx'), isNotNull);
    expect(archive.findFile('datasource/datos.csv'), isNotNull);

    final loadCache = p.join(tempDirectory.path, 'LoadCache');
    final loadedProject = await repository.load(
      filePath,
      cacheDirectory: loadCache,
    );
    expect(loadedProject.id, sourceProject.id);
    expect(loadedProject.name, sourceProject.name);
    expect(loadedProject.createdAt, sourceProject.createdAt);
    expect(loadedProject.mappingAssignments, sourceProject.mappingAssignments);
    expect(loadedProject.filePath, filePath);
    expect(loadedProject.isDirty, isFalse);
    expect(loadedProject.embeddedTemplatePath, isNotNull);
    expect(loadedProject.embeddedDatasourcePath, isNotNull);
    expect(File(loadedProject.embeddedTemplatePath!).existsSync(), isTrue);
    expect(File(loadedProject.embeddedDatasourcePath!).existsSync(), isTrue);
  });

  test('save sobre mismo path reemplaza sin dejar tmp o bak', () async {
    final filePath = p.join(tempDirectory.path, 'proyecto_reemplazo.fork');
    final firstProject = Project(
      id: 'project-1',
      name: 'Proyecto Inicial',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final secondProject = firstProject.copyWith(
      name: 'Proyecto Actualizado',
      updatedAt: DateTime.utc(2026, 1, 3),
    );

    await repository.save(project: firstProject, filePath: filePath);
    await repository.save(project: secondProject, filePath: filePath);

    final loaded = await repository.load(
      filePath,
      cacheDirectory: p.join(tempDirectory.path, 'Cache'),
    );
    expect(loaded.name, 'Proyecto Actualizado');

    final siblings = await tempDirectory.list().toList();
    final tempOrBakFiles = siblings
        .whereType<File>()
        .map((entry) => p.basename(entry.path))
        .where(
          (name) =>
              name.contains('.fork.') ||
              name.endsWith('.tmp') ||
              name.endsWith('.bak'),
        )
        .toList();

    expect(tempOrBakFiles, isEmpty);
  });

  test('rechaza extensión distinta de .fork', () async {
    final filePath = p.join(tempDirectory.path, 'otro.json');
    await File(filePath).writeAsString('{}');

    expect(
      () => repository.load(
        filePath,
        cacheDirectory: p.join(tempDirectory.path, 'Cache'),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('.fork'),
        ),
      ),
    );
  });

  test('rechaza formato JSON antiguo con mensaje claro', () async {
    final filePath = p.join(tempDirectory.path, 'legacy.fork');
    await File(filePath).writeAsString(
      jsonEncode(<String, dynamic>{
        'id': 'old',
        'name': 'Viejo',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      }),
    );

    expect(
      () => repository.load(
        filePath,
        cacheDirectory: p.join(tempDirectory.path, 'Cache'),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('formato antiguo'),
        ),
      ),
    );
  });

  test('rechaza ZIP inválido', () async {
    final filePath = p.join(tempDirectory.path, 'roto.fork');
    await File(filePath).writeAsBytes(<int>[0, 1, 2, 3, 4, 5]);

    expect(
      () => repository.load(
        filePath,
        cacheDirectory: p.join(tempDirectory.path, 'Cache'),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
