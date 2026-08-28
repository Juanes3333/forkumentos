import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/app/app.dart';
import 'package:forkumentos/app/bootstrap.dart';
import 'package:forkumentos/core/launch/launch_arguments.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/storage/storage_providers.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';

Future<void> main(List<String> args) async {
  final dependencies = await bootstrap();

  runApp(
    ProviderScope(
      overrides: <Override>[
        loggingServiceProvider.overrideWithValue(dependencies.loggingService),
        keyValueStorageProvider.overrideWithValue(dependencies.keyValueStorage),
        windowServiceProvider.overrideWithValue(dependencies.windowService),
        launchArgumentsProvider.overrideWithValue(args),
      ],
      child: const App(),
    ),
  );
}
