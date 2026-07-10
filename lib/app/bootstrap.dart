import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Initializes application configurations and services.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
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
}
