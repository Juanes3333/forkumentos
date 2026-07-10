import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/storage/file_key_value_storage.dart';

void main() {
  late Directory tempDirectory;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('forkumentos_test_');
  });

  tearDown(() {
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test('read de clave inexistente retorna null', () async {
    final storage = FileKeyValueStorage(
      supportDirectoryProvider: () async => tempDirectory,
    );

    await storage.initialize();

    expect(await storage.read('missing'), isNull);
  });

  test('write read delete y clear persisten correctamente', () async {
    final storage = FileKeyValueStorage(
      supportDirectoryProvider: () async => tempDirectory,
    );

    await storage.initialize();
    await storage.write('alpha', 'A');
    await storage.write('beta', 'B');

    expect(await storage.read('alpha'), 'A');
    expect(await storage.read('beta'), 'B');

    final reloadedStorage = FileKeyValueStorage(
      supportDirectoryProvider: () async => tempDirectory,
    );
    await reloadedStorage.initialize();

    expect(await reloadedStorage.read('alpha'), 'A');
    expect(await reloadedStorage.read('beta'), 'B');

    await reloadedStorage.delete('alpha');
    expect(await reloadedStorage.read('alpha'), isNull);
    expect(await reloadedStorage.read('beta'), 'B');

    await reloadedStorage.clear();
    expect(await reloadedStorage.read('beta'), isNull);
  });
}
