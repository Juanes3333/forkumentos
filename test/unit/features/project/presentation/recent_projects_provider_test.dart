import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/storage/storage_providers.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';

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
        .record(filePath: '/tmp/uno.forkumentos.json', name: 'Uno');

    final entries = container.read(recentProjectsProvider).valueOrNull;
    expect(entries, hasLength(1));
    expect(entries?.first.filePath, '/tmp/uno.forkumentos.json');
  });

  test('record deduplica por filePath moviendo la entrada al frente', () async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await container.read(recentProjectsProvider.future);
    final notifier = container.read(recentProjectsProvider.notifier);

    await notifier.record(filePath: '/tmp/uno.forkumentos.json', name: 'Uno');
    await notifier.record(filePath: '/tmp/dos.forkumentos.json', name: 'Dos');
    await notifier.record(
      filePath: '/tmp/uno.forkumentos.json',
      name: 'Uno Renombrado',
    );

    final entries = container.read(recentProjectsProvider).valueOrNull;
    expect(entries, hasLength(2));
    expect(entries?.first.filePath, '/tmp/uno.forkumentos.json');
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
          filePath: '/tmp/proyecto_$i.forkumentos.json',
          name: 'Proyecto $i',
        );
      }

      final entries = container.read(recentProjectsProvider).valueOrNull;
      expect(entries, hasLength(10));
      expect(entries?.first.filePath, '/tmp/proyecto_11.forkumentos.json');
      expect(
        entries?.any(
          (entry) => entry.filePath == '/tmp/proyecto_0.forkumentos.json',
        ),
        isFalse,
      );
    },
  );
}

ProviderContainer _createContainer() {
  return ProviderContainer(
    overrides: <Override>[
      keyValueStorageProvider.overrideWithValue(FakeKeyValueStorage()),
    ],
  );
}
