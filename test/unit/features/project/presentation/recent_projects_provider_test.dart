import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/storage/storage_providers.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';
import 'package:path/path.dart' as p;

import '../../../../support/fakes.dart';

void main() {
  test('build inicia con lista vacía cuando no hay historial', () async {
    final container = _createContainer();
    addTearDown(container.dispose);

    final state = await container.read(recentProjectsProvider.future);

    expect(state, isEmpty);
  });

  test('record agrega una entrada nueva al inicio de la lista', () async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await container.read(recentProjectsProvider.future);

    await container
        .read(recentProjectsProvider.notifier)
        .record(filePath: '/tmp/uno.fork', name: 'Uno');

    final entries = container.read(recentProjectsProvider).valueOrNull;
    expect(entries, hasLength(1));
    expect(entries?.first.filePath, '/tmp/uno.fork');
  });

  test('record deduplica por filePath moviendo la entrada al frente', () async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await container.read(recentProjectsProvider.future);
    final notifier = container.read(recentProjectsProvider.notifier);

    await notifier.record(filePath: '/tmp/uno.fork', name: 'Uno');
    await notifier.record(filePath: '/tmp/dos.fork', name: 'Dos');
    await notifier.record(filePath: '/tmp/uno.fork', name: 'Uno Renombrado');

    final entries = container.read(recentProjectsProvider).valueOrNull;
    expect(entries, hasLength(2));
    expect(entries?.first.filePath, '/tmp/uno.fork');
    expect(entries?.first.name, 'Uno Renombrado');
  });

  test(
    'record limita el historial a 10 entradas descartando las más antiguas',
    () async {
      final container = _createContainer();
      addTearDown(container.dispose);
      await container.read(recentProjectsProvider.future);
      final notifier = container.read(recentProjectsProvider.notifier);

      for (var i = 0; i < 12; i++) {
        await notifier.record(
          filePath: '/tmp/proyecto_$i.fork',
          name: 'Proyecto $i',
        );
      }

      final entries = container.read(recentProjectsProvider).valueOrNull;
      expect(entries, hasLength(10));
      expect(entries?.first.filePath, '/tmp/proyecto_11.fork');
      expect(
        entries?.any((entry) => entry.filePath == '/tmp/proyecto_0.fork'),
        isFalse,
      );
    },
  );

  test('remove elimina una entrada del historial', () async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await container.read(recentProjectsProvider.future);
    final notifier = container.read(recentProjectsProvider.notifier);

    await notifier.record(filePath: '/tmp/uno.fork', name: 'Uno');
    await notifier.record(filePath: '/tmp/dos.fork', name: 'Dos');
    await notifier.remove('/tmp/uno.fork');

    final entries = container.read(recentProjectsProvider).valueOrNull;
    expect(entries, hasLength(1));
    expect(entries?.first.filePath, '/tmp/dos.fork');
  });

  test('clear vacía el historial', () async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await container.read(recentProjectsProvider.future);
    final notifier = container.read(recentProjectsProvider.notifier);

    await notifier.record(filePath: '/tmp/uno.fork', name: 'Uno');
    await notifier.clear();

    final entries = container.read(recentProjectsProvider).valueOrNull;
    expect(entries, isEmpty);
  });

  test('pruneMissing elimina entradas cuyo archivo ya no existe', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'forkumentos_recent_prune_',
    );
    addTearDown(() async {
      await tempDir.delete(recursive: true);
    });

    final existingPath = p.join(tempDir.path, 'existe.fork');
    final missingPath = p.join(tempDir.path, 'faltante.fork');
    await File(existingPath).writeAsString('{}');

    final container = _createContainer();
    addTearDown(container.dispose);
    await container.read(recentProjectsProvider.future);
    final notifier = container.read(recentProjectsProvider.notifier);

    await notifier.record(filePath: missingPath, name: 'Faltante');
    await notifier.record(filePath: existingPath, name: 'Existe');

    final pruned = await notifier.pruneMissing();

    expect(pruned, hasLength(1));
    expect(pruned.single.filePath, existingPath);
  });
}

ProviderContainer _createContainer() {
  return ProviderContainer(
    overrides: <Override>[
      keyValueStorageProvider.overrideWithValue(FakeKeyValueStorage()),
    ],
  );
}
