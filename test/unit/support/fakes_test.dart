import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  test('FakeKeyValueStorage soporta ciclo CRUD completo', () async {
    final storage = FakeKeyValueStorage();

    expect(storage.isInitialized, isFalse);
    await storage.initialize();
    expect(storage.isInitialized, isTrue);

    expect(await storage.read('missing'), isNull);

    await storage.write('one', '1');
    await storage.write('two', '2');
    expect(await storage.read('one'), '1');
    expect(await storage.read('two'), '2');

    await storage.delete('one');
    expect(await storage.read('one'), isNull);
    expect(await storage.read('two'), '2');

    await storage.clear();
    expect(await storage.read('two'), isNull);
  });

  test('FakeLoggingService registra entradas emitidas', () {
    final logger = FakeLoggingService()
      ..debug('debug', module: 'Test')
      ..info('info', module: 'Test')
      ..warning('warning', module: 'Test')
      ..error('error', module: 'Test');

    final entries = logger.entries;
    expect(entries, hasLength(4));
    expect(entries[0], '[DEBUG][Test] debug');
    expect(entries[1], '[INFO][Test] info');
    expect(entries[2], '[WARN][Test] warning');
    expect(entries[3], '[ERROR][Test] error');
  });
}
