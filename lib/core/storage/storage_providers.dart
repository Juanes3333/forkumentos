import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/storage/key_value_storage.dart';

final keyValueStorageProvider = Provider<KeyValueStorage>((ref) {
  throw UnimplementedError(
    'keyValueStorageProvider debe ser sobrescrito en bootstrap',
  );
});
