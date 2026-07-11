import 'dart:io';

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
