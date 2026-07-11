import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/settings/data/settings_store.dart';
import 'package:forkumentos/features/settings/domain/app_settings.dart';

import '../../../../support/fakes.dart';

void main() {
  Future<String> fakeRoot() async => r'C:\Users\test\Forkumentos';

  test('load sin datos usa defaults', () async {
    final storage = FakeKeyValueStorage();
    final store = SettingsStore(storage, defaultRoot: fakeRoot);

    final settings = await store.load();
    expect(settings.theme, SettingsDefaults.theme);
    expect(settings.workspaceRoot, r'C:\Users\test\Forkumentos');
  });

  test('save y load persisten workspace y tema', () async {
    final storage = FakeKeyValueStorage();
    final store = SettingsStore(storage, defaultRoot: fakeRoot);

    const original = AppSettings(
      workspaceRoot: r'C:\Users\test\ForkumentosCustom',
      theme: AppThemePreference.light,
    );
    await store.save(original);

    final restored = await store.load();
    expect(restored.workspaceRoot, original.workspaceRoot);
    expect(restored.theme, AppThemePreference.light);
  });

  test('JSON corrupto cae a defaults', () async {
    final storage = FakeKeyValueStorage();
    await storage.write(settingsStorageKey, '{no-json');
    final store = SettingsStore(storage, defaultRoot: fakeRoot);

    final settings = await store.load();
    expect(settings.theme, SettingsDefaults.theme);
    expect(settings.workspaceRoot, r'C:\Users\test\Forkumentos');
  });
}
