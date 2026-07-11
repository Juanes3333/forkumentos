import 'dart:io';

import 'package:forkumentos/core/logging/logging_service.dart';

/// Registers `.fork` → current exe under HKCU (per-user, no installer).
///
/// ponytail: HKCU registration; MSI/Inno can replace later.
Future<void> registerForkFileAssociation(LoggingService logging) async {
  if (!Platform.isWindows) {
    return;
  }

  final exe = Platform.resolvedExecutable;
  const progId = 'Forkumentos.Project';

  try {
    await _regAdd(r'HKCU\Software\Classes\.fork', progId);
    await _regAdd('HKCU\\Software\\Classes\\$progId', 'Forkumentos Project');
    await _regAdd('HKCU\\Software\\Classes\\$progId\\DefaultIcon', '"$exe",0');
    await _regAdd(
      'HKCU\\Software\\Classes\\$progId\\shell\\open\\command',
      '"$exe" "%1"',
    );
    logging.info(
      'Asociación .fork registrada (HKCU)',
      module: 'FileAssociation',
    );
  } on Object catch (error, stackTrace) {
    logging.warning(
      'No se pudo registrar la asociación .fork',
      module: 'FileAssociation',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<void> _regAdd(String key, String value) async {
  final result = await Process.run('reg', <String>[
    'add',
    key,
    '/ve',
    '/d',
    value,
    '/f',
  ]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'reg',
      <String>['add', key, '/ve', '/d', value, '/f'],
      result.stderr.toString(),
      result.exitCode,
    );
  }
}
