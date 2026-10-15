import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/settings/data/update_checker.dart';
import 'package:forkumentos/shared/widgets/about_forkumentos_dialog.dart';

/// Provider que expone el resultado de la última verificación de
/// actualizaciones.
final updateCheckProvider =
    AsyncNotifierProvider<UpdateCheckNotifier, UpdateCheckResult?>(
      UpdateCheckNotifier.new,
    );

/// Notificador que maneja la verificación de actualizaciones a demanda.
base class UpdateCheckNotifier extends AsyncNotifier<UpdateCheckResult?> {
  @override
  Future<UpdateCheckResult?> build() async {
    // No verificar automáticamente al construir — esperar a que el usuario
    // presione el botón. Devolver null como estado inicial.
    return null;
  }

  /// Ejecuta la verificación de actualizaciones contra GitHub.
  Future<void> checkForUpdates() async {
    state = const AsyncLoading<UpdateCheckResult?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      return UpdateChecker.check(currentVersion: forkumentosVersion);
    });
  }
}

/// Descarga y lanza el instalador de una actualización. Existe como provider
/// para que los tests puedan sustituirlo sin tocar la red ni cerrar el
/// proceso.
final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => const UpdateInstaller(),
);

class UpdateInstaller {
  const UpdateInstaller();

  Future<File> download({
    required String downloadUrl,
    required String version,
    void Function(int received, int total)? onProgress,
  }) {
    return UpdateChecker.downloadInstaller(
      downloadUrl: downloadUrl,
      version: version,
      onProgress: onProgress,
    );
  }

  Future<void> launchAndExit(File installer) {
    return UpdateChecker.launchInstallerAndExit(installer);
  }
}
