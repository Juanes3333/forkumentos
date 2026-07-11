import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/storage/storage_providers.dart';
import 'package:forkumentos/core/workspace/workspace_paths.dart';
import 'package:forkumentos/features/settings/data/settings_store.dart';
import 'package:forkumentos/features/settings/domain/app_settings.dart';

final settingsStoreProvider = Provider<SettingsStore>((ref) {
  return SettingsStore(ref.watch(keyValueStorageProvider));
});

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

final class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final settings = await ref.read(settingsStoreProvider).load();
    await WorkspacePaths(root: settings.workspaceRoot).ensureAll();
    return settings;
  }

  Future<void> setWorkspaceRoot(String root) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final normalized = root.trim();
    if (normalized.isEmpty || normalized == current.workspaceRoot) {
      return;
    }
    await _commit(current.copyWith(workspaceRoot: normalized));
  }

  Future<void> setTheme(AppThemePreference theme) async {
    final current = state.valueOrNull;
    if (current == null || current.theme == theme) {
      return;
    }
    await _commit(current.copyWith(theme: theme));
  }

  Future<void> setRecentProjectsLimit(int limit) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final clamped = limit.clamp(1, SettingsDefaults.maxRecentProjectsLimit);
    if (clamped == current.recentProjectsLimit) {
      return;
    }
    await _commit(current.copyWith(recentProjectsLimit: clamped));
  }

  Future<void> setOpenRecentOnStartup({required bool value}) async {
    final current = state.valueOrNull;
    if (current == null || current.openRecentOnStartup == value) {
      return;
    }
    await _commit(current.copyWith(openRecentOnStartup: value));
  }

  Future<void> setConfirmBeforeClosing({required bool value}) async {
    final current = state.valueOrNull;
    if (current == null || current.confirmBeforeClosing == value) {
      return;
    }
    await _commit(current.copyWith(confirmBeforeClosing: value));
  }

  Future<void> setAutosaveIntervalSeconds(int seconds) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final normalized = seconds < 0 ? 0 : seconds;
    if (normalized == current.autosaveIntervalSeconds) {
      return;
    }
    await _commit(current.copyWith(autosaveIntervalSeconds: normalized));
  }

  Future<void> setDefaultExportFormat(String format) async {
    final current = state.valueOrNull;
    if (current == null ||
        !ExportFormatSetting.values.contains(format) ||
        current.defaultExportFormat == format) {
      return;
    }
    await _commit(current.copyWith(defaultExportFormat: format));
  }

  Future<void> setDefaultCreateZip({required bool value}) async {
    final current = state.valueOrNull;
    if (current == null || current.defaultCreateZip == value) {
      return;
    }
    await _commit(current.copyWith(defaultCreateZip: value));
  }

  Future<void> restoreDefaults() async {
    final defaultRoot = await WorkspacePaths.defaultRoot();
    final next = AppSettings.defaults(workspaceRoot: defaultRoot);
    await WorkspacePaths(root: next.workspaceRoot).ensureAll();
    await ref.read(settingsStoreProvider).save(next);
    state = AsyncData(next);
  }

  Future<void> _commit(AppSettings next) async {
    final current = state.valueOrNull;
    if (current != null && next.workspaceRoot != current.workspaceRoot) {
      await WorkspacePaths(root: next.workspaceRoot).ensureAll();
    }
    await ref.read(settingsStoreProvider).save(next);
    state = AsyncData(next);
  }
}

/// Cross-feature read of the workspace root (settings.mdc contract).
final workspaceRootProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  return settings?.workspaceRoot ?? '';
});

final workspacePathsProvider = Provider<WorkspacePaths?>((ref) {
  final root = ref.watch(workspaceRootProvider);
  if (root.isEmpty) {
    return null;
  }
  return WorkspacePaths(root: root);
});

final themePreferenceProvider = Provider<AppThemePreference>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.theme ??
      SettingsDefaults.theme;
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(themePreferenceProvider)) {
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.system => ThemeMode.system,
  };
});

final recentProjectsLimitProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.recentProjectsLimit ??
      SettingsDefaults.recentProjectsLimit;
});

final openRecentOnStartupProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.openRecentOnStartup ??
      SettingsDefaults.openRecentOnStartup;
});

final confirmBeforeClosingProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.confirmBeforeClosing ??
      SettingsDefaults.confirmBeforeClosing;
});

final autosaveIntervalSecondsProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.autosaveIntervalSeconds ??
      SettingsDefaults.autosaveIntervalSeconds;
});

final defaultExportFormatProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.defaultExportFormat ??
      SettingsDefaults.defaultExportFormat;
});

final defaultCreateZipProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).valueOrNull?.defaultCreateZip ??
      SettingsDefaults.defaultCreateZip;
});
