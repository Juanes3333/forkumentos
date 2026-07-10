import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/window/window_service.dart';

final windowServiceProvider = Provider<WindowService>((ref) {
  throw UnimplementedError(
    'windowServiceProvider debe ser sobrescrito en bootstrap',
  );
});
