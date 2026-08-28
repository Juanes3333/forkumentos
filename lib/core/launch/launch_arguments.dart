import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Command-line arguments the process was started with.
///
/// `main()` receives argv on desktop and overrides this with the real list.
/// The default falls back to [Platform.executableArguments], which only carries
/// the launch path in AOT release builds — under `flutter run` it is empty,
/// which is why "abrir en nueva ventana" used to land on the start screen.
final launchArgumentsProvider = Provider<List<String>>(
  (ref) => Platform.executableArguments,
);

/// First existing path among [args] that ends with `.fork` (case-insensitive).
/// Other arguments are ignored.
String? resolveLaunchProjectPath(List<String> args) {
  for (final arg in args) {
    if (!arg.toLowerCase().endsWith('.fork')) {
      continue;
    }
    // ignore: avoid_slow_async_io
    if (File(arg).existsSync()) {
      return arg;
    }
  }
  return null;
}

/// True when [args] contain the exact flag `--new`.
bool wantsNewProject(List<String> args) => args.contains('--new');
