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
    expect(settings.recentProjectsLimit, SettingsDefaults.recentProjectsLimit);
    expect(settings.openRecentOnStartup, SettingsDefaults.openRecentOnStartup);
    expect(
      settings.confirmBeforeClosing,
      SettingsDefaults.confirmBeforeClosing,
    );
    expect(
      settings.autosaveIntervalSeconds,
      SettingsDefaults.autosaveIntervalSeconds,
    );
    expect(settings.defaultExportFormat, SettingsDefaults.defaultExportFormat);
    expect(settings.defaultCreateZip, SettingsDefaults.defaultCreateZip);
  });

  test('save y load persisten todos los campos', () async {
    final storage = FakeKeyValueStorage();
    final store = SettingsStore(storage, defaultRoot: fakeRoot);

    const original = AppSettings(
      workspaceRoot: r'C:\Users\test\ForkumentosCustom',
      theme: AppThemePreference.system,
      recentProjectsLimit: 5,
      openRecentOnStartup: true,
      confirmBeforeClosing: false,
      autosaveIntervalSeconds: 120,
      defaultExportFormat: ExportFormatSetting.pdf,
      defaultCreateZip: true,
    );
    await store.save(original);

    final restored = await store.load();
    expect(restored.workspaceRoot, original.workspaceRoot);
    expect(restored.theme, AppThemePreference.system);
    expect(restored.recentProjectsLimit, 5);
    expect(restored.openRecentOnStartup, isTrue);
    expect(restored.confirmBeforeClosing, isFalse);
    expect(restored.autosaveIntervalSeconds, 120);
    expect(restored.defaultExportFormat, ExportFormatSetting.pdf);
    expect(restored.defaultCreateZip, isTrue);
  });

  test('JSON corrupto cae a defaults', () async {
    final storage = FakeKeyValueStorage();
    await storage.write(settingsStorageKey, '{no-json');
    final store = SettingsStore(storage, defaultRoot: fakeRoot);

    final settings = await store.load();
    expect(settings.theme, SettingsDefaults.theme);
    expect(settings.workspaceRoot, r'C:\Users\test\Forkumentos');
    expect(settings.recentProjectsLimit, SettingsDefaults.recentProjectsLimit);
  });

  test('JSON parcial rellena campos nuevos con defaults', () async {
    final storage = FakeKeyValueStorage();
    await storage.write(
      settingsStorageKey,
      r'{"workspaceRoot":"C:\\old","theme":"light"}',
    );
    final store = SettingsStore(storage, defaultRoot: fakeRoot);

    final settings = await store.load();
    expect(settings.workspaceRoot, r'C:\old');
    expect(settings.theme, AppThemePreference.light);
    expect(settings.recentProjectsLimit, SettingsDefaults.recentProjectsLimit);
    expect(settings.defaultExportFormat, SettingsDefaults.defaultExportFormat);
  });

  test('formato de exportación inválido cae al default', () async {
    final settings = AppSettings.fromJson(<String, dynamic>{
      'workspaceRoot': r'C:\x',
      'theme': 'dark',
      'defaultExportFormat': 'xlsx',
    }, defaultWorkspaceRoot: r'C:\default');
    expect(settings.defaultExportFormat, SettingsDefaults.defaultExportFormat);
  });
}
