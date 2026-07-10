import 'dart:convert';
import 'dart:io';

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

  test('save y load persisten el proyecto en JSON', () async {
    final sourceProject = Project(
      id: 'project-1',
      name: 'Proyecto Persistente',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final filePath = p.join(
      tempDirectory.path,
      'proyecto_persistente.forkumentos.json',
    );

    final savedProject = await repository.save(
      project: sourceProject,
      filePath: filePath,
    );
    expect(savedProject.filePath, filePath);

    final rawFileContent = await File(filePath).readAsString();
    final persistedJson = jsonDecode(rawFileContent) as Map<String, dynamic>;
    expect(persistedJson.containsKey('filePath'), isFalse);

    final loadedProject = await repository.load(filePath);
    expect(loadedProject.id, sourceProject.id);
    expect(loadedProject.name, sourceProject.name);
    expect(loadedProject.createdAt, sourceProject.createdAt);
    expect(loadedProject.updatedAt, savedProject.updatedAt);
    expect(loadedProject.filePath, filePath);
  });

  test(
    'save sobre mismo path reemplaza contenido sin dejar tmp o bak',
    () async {
      final filePath = p.join(
        tempDirectory.path,
        'proyecto_reemplazo.forkumentos.json',
      );
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

      final rawFileContent = await File(filePath).readAsString();
      final persistedJson = jsonDecode(rawFileContent) as Map<String, dynamic>;
      expect(persistedJson['name'], 'Proyecto Actualizado');

      final siblings = await tempDirectory.list().toList();
      final tempOrBakFiles = siblings
          .whereType<File>()
          .map((entry) => p.basename(entry.path))
          .where(
            (name) =>
                name.contains('.forkumentos.json.') ||
                name.endsWith('.tmp') ||
                name.endsWith('.bak'),
          )
          .toList();

      expect(tempOrBakFiles, isEmpty);
    },
  );

  test('rechaza archivo JSON inválido', () async {
    final filePath = p.join(
      tempDirectory.path,
      'invalid_json.forkumentos.json',
    );
    await File(filePath).writeAsString('[1, 2, 3]');

    expect(() => repository.load(filePath), throwsA(isA<FormatException>()));
  });

  test('rechaza estructura de proyecto malformada', () async {
    final filePath = p.join(
      tempDirectory.path,
      'malformed_project.forkumentos.json',
    );
    await File(
      filePath,
    ).writeAsString(jsonEncode(<String, dynamic>{'id': 'only-id'}));

    expect(() => repository.load(filePath), throwsA(isA<Object>()));
  });
}
