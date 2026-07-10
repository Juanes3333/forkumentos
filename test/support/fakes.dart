import 'package:forkumentos/core/logging/logging_service.dart';
import 'package:forkumentos/core/storage/key_value_storage.dart';

final class FakeLoggingService implements LoggingService {
  final List<String> entries = <String>[];

  @override
  void debug(String message, {String? module}) {
    entries.add(_format('DEBUG', message, module: module));
  }

  @override
  void info(String message, {String? module}) {
    entries.add(_format('INFO', message, module: module));
  }

  @override
  void warning(
    String message, {
    String? module,
    Object? error,
    StackTrace? stackTrace,
  }) {
    entries.add(_format('WARN', message, module: module));
  }

  @override
  void error(
    String message, {
    String? module,
    Object? error,
    StackTrace? stackTrace,
  }) {
    entries.add(_format('ERROR', message, module: module));
  }

  String _format(String level, String message, {String? module}) {
    if (module == null || module.isEmpty) {
      return '[$level] $message';
    }

    return '[$level][$module] $message';
  }
}

final class FakeKeyValueStorage implements KeyValueStorage {
  final Map<String, String> _values = <String, String>{};
  bool isInitialized = false;

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }
}
