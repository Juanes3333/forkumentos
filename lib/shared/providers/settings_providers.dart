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
    final next = current.copyWith(workspaceRoot: normalized);
    await WorkspacePaths(root: next.workspaceRoot).ensureAll();
    await ref.read(settingsStoreProvider).save(next);
    state = AsyncData(next);
  }

  Future<void> setTheme(AppThemePreference theme) async {
    final current = state.valueOrNull;
    if (current == null || current.theme == theme) {
      return;
    }
    final next = current.copyWith(theme: theme);
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
  };
});
