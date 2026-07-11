import 'dart:convert';

import 'package:forkumentos/core/storage/key_value_storage.dart';
import 'package:forkumentos/core/workspace/workspace_paths.dart';
import 'package:forkumentos/features/settings/domain/app_settings.dart';

const settingsStorageKey = 'app.settings.v1';

final class SettingsStore {
  SettingsStore(this._storage, {Future<String> Function()? defaultRoot})
    : _defaultRoot = defaultRoot ?? WorkspacePaths.defaultRoot;

  final KeyValueStorage _storage;
  final Future<String> Function() _defaultRoot;

  Future<AppSettings> load() async {
    final defaultRoot = await _defaultRoot();
    final raw = await _storage.read(settingsStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return AppSettings.defaults(workspaceRoot: defaultRoot);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return AppSettings.defaults(workspaceRoot: defaultRoot);
      }
      return AppSettings.fromJson(
        decoded.cast<String, dynamic>(),
        defaultWorkspaceRoot: defaultRoot,
      );
    } on FormatException {
      return AppSettings.defaults(workspaceRoot: defaultRoot);
    }
  }

  Future<void> save(AppSettings settings) async {
    await _storage.write(settingsStorageKey, jsonEncode(settings.toJson()));
  }
}
