import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/storage/storage_providers.dart';

import '../../../support/fakes.dart';

void main() {
  test('overrides de providers son consumidos por container', () async {
    final fakeLogger = FakeLoggingService();
    final fakeStorage = FakeKeyValueStorage();
    await fakeStorage.initialize();

    final container = ProviderContainer(
      overrides: <Override>[
        loggingServiceProvider.overrideWithValue(fakeLogger),
        keyValueStorageProvider.overrideWithValue(fakeStorage),
      ],
    );
    addTearDown(container.dispose);

    final resolvedLogger = container.read(loggingServiceProvider);
    final resolvedStorage = container.read(keyValueStorageProvider);

    expect(identical(resolvedLogger, fakeLogger), isTrue);
    expect(identical(resolvedStorage, fakeStorage), isTrue);

    resolvedLogger.info('provider consumed', module: 'Test');
    expect(fakeLogger.entries, contains('[INFO][Test] provider consumed'));

    await resolvedStorage.write('k', 'v');
    expect(await resolvedStorage.read('k'), 'v');
  });
}
