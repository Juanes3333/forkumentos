import 'package:flutter/widgets.dart';
import 'package:forkumentos/core/logging/app_logger.dart';
import 'package:forkumentos/core/logging/logging_service.dart';
import 'package:forkumentos/core/storage/file_key_value_storage.dart';
import 'package:forkumentos/core/storage/key_value_storage.dart';
import 'package:window_manager/window_manager.dart';

@immutable
final class AppBootstrapDependencies {
  const AppBootstrapDependencies({
    required this.loggingService,
    required this.keyValueStorage,
  });

  final LoggingService loggingService;
  final KeyValueStorage keyValueStorage;
}

Future<AppBootstrapDependencies> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final loggingService = AppLogger()
    ..info('Iniciando bootstrap', module: 'Bootstrap');

  try {
    final keyValueStorage = FileKeyValueStorage();
    await keyValueStorage.initialize();
    loggingService.info('Storage inicializado', module: 'Bootstrap');

    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      title: 'Forkumentos',
      size: Size(1280, 800),
      minimumSize: Size(1024, 720),
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    });

    loggingService.info('Bootstrap completado', module: 'Bootstrap');

    return AppBootstrapDependencies(
      loggingService: loggingService,
      keyValueStorage: keyValueStorage,
    );
  } catch (error, stackTrace) {
    loggingService.error(
      'Error en bootstrap',
      module: 'Bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
