import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/project/data/recent_projects_store.dart';
import 'package:forkumentos/features/project/domain/recent_project.dart';

import '../../../../support/fakes.dart';

const _recentProjectsStorageKey = 'project.recentProjects.v1';

void main() {
  test('read retorna lista vacía cuando no hay datos almacenados', () async {
    final storage = FakeKeyValueStorage();
    await storage.initialize();
    final store = RecentProjectsStore(storage);

    final entries = await store.read();

    expect(entries, isEmpty);
  });

  test('write y read persisten entradas en orden', () async {
    final storage = FakeKeyValueStorage();
    await storage.initialize();
    final store = RecentProjectsStore(storage);

    final entries = <RecentProject>[
      RecentProject(
        filePath: '/tmp/uno.fork',
        name: 'Uno',
        lastOpenedAt: DateTime.utc(2026),
      ),
      RecentProject(
        filePath: '/tmp/dos.fork',
        name: 'Dos',
        lastOpenedAt: DateTime.utc(2026, 1, 2),
      ),
    ];
    await store.write(entries);

    final restored = await store.read();

    expect(restored, hasLength(2));
    expect(restored[0].filePath, '/tmp/uno.fork');
    expect(restored[1].filePath, '/tmp/dos.fork');
  });

  test(
    'read retorna lista vacía cuando el contenido no es JSON válido',
    () async {
      final storage = FakeKeyValueStorage();
      await storage.initialize();
      await storage.write(_recentProjectsStorageKey, 'no es json');
      final store = RecentProjectsStore(storage);

      final entries = await store.read();

      expect(entries, isEmpty);
    },
  );

  test('read retorna lista vacía cuando el contenido tiene una estructura '
      'inesperada', () async {
    final storage = FakeKeyValueStorage();
    await storage.initialize();
    await storage.write(_recentProjectsStorageKey, '{"not":"a list"}');
    final store = RecentProjectsStore(storage);

    final entries = await store.read();

    expect(entries, isEmpty);
  });
}
