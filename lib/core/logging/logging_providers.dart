import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/logging/logging_service.dart';

final loggingServiceProvider = Provider<LoggingService>((ref) {
  throw UnimplementedError(
    'loggingServiceProvider debe ser sobrescrito en bootstrap',
  );
});
