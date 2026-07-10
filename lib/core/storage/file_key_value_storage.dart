import 'dart:convert';
import 'dart:io';

import 'package:forkumentos/core/storage/key_value_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class FileKeyValueStorage implements KeyValueStorage {
  FileKeyValueStorage({
    Future<Directory> Function()? supportDirectoryProvider,
    this._fileName = 'forkumentos_storage.json',
  }) : _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectoryProvider;
  final String _fileName;

  File? _storageFile;
  Map<String, String> _values = <String, String>{};

  @override
  Future<void> initialize() async {
    final supportDirectory = await _supportDirectoryProvider();
    await supportDirectory.create(recursive: true);

    final storageFile = File(p.join(supportDirectory.path, _fileName));
    _storageFile = storageFile;
    await storageFile.create();

    final rawContent = await storageFile.readAsString();
    if (rawContent.trim().isEmpty) {
      _values = <String, String>{};
      await _persistValues();
      return;
    }

    final parsed = jsonDecode(rawContent);
    if (parsed is Map<String, dynamic>) {
      _values = Map<String, String>.fromEntries(
        parsed.entries
            .where((entry) => entry.value is String)
            .map(
              (entry) =>
                  MapEntry<String, String>(entry.key, entry.value as String),
            ),
      );
      return;
    }

    _values = <String, String>{};
    await _persistValues();
  }

  @override
  Future<String?> read(String key) async {
    _ensureInitialized();
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _ensureInitialized();
    _values[key] = value;
    await _persistValues();
  }

  @override
  Future<void> delete(String key) async {
    _ensureInitialized();
    _values.remove(key);
    await _persistValues();
  }

  @override
  Future<void> clear() async {
    _ensureInitialized();
    _values = <String, String>{};
    await _persistValues();
  }

  void _ensureInitialized() {
    if (_storageFile == null) {
      throw StateError(
        'FileKeyValueStorage.initialize() debe ejecutarse antes de usarlo',
      );
    }
  }

  Future<void> _persistValues() async {
    final storageFile = _storageFile;
    if (storageFile == null) {
      throw StateError(
        'FileKeyValueStorage.initialize() debe ejecutarse antes de persistir',
      );
    }

    await storageFile.writeAsString(jsonEncode(_values));
  }
}
