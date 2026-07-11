import 'dart:io';

/// Spawns another Forkumentos process (multi-window via second process).
Future<void> spawnAppInstance({
  String? projectPath,
  bool newProject = false,
}) async {
  final args = <String>[
    if (projectPath != null) projectPath,
    if (newProject) '--new',
  ];
  await Process.start(
    Platform.resolvedExecutable,
    args,
    mode: ProcessStartMode.detached,
  );
}
