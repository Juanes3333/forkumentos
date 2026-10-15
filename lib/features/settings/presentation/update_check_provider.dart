import 'dart:io';

import 'package:flutter/foundation.dart';
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

enum UpdateInstallPhase { idle, downloading, ready, failed }

/// Estado de la descarga del instalador. Vive en un provider (no en el
/// `State` de un widget) para que cerrar y reabrir Ajustes no permita una
/// segunda descarga.
@immutable
final class UpdateInstallState {
  const UpdateInstallState({
    this.phase = UpdateInstallPhase.idle,
    this.progress,
    this.file,
  });

  final UpdateInstallPhase phase;

  /// Fracción descargada (0.0 a 1.0), o `null` si no se conoce el tamaño.
  final double? progress;

  /// Instalador ya descargado cuando [phase] es [UpdateInstallPhase.ready].
  final File? file;
}

final updateInstallProvider =
    NotifierProvider<UpdateInstallNotifier, UpdateInstallState>(
      UpdateInstallNotifier.new,
    );

base class UpdateInstallNotifier extends Notifier<UpdateInstallState> {
  @override
  UpdateInstallState build() => const UpdateInstallState();

  /// Descarga el instalador de [result]. Devuelve `true` si queda listo para
  /// lanzar. Si ya hay una descarga en curso o terminada no inicia otra.
  Future<bool> download(UpdateCheckResult result) async {
    final current = state;
    if (current.phase == UpdateInstallPhase.downloading) {
      return false;
    }
    if (current.phase == UpdateInstallPhase.ready) {
      return true;
    }
    state = const UpdateInstallState(phase: UpdateInstallPhase.downloading);
    try {
      final file = await ref
          .read(updateInstallerProvider)
          .download(
            downloadUrl: result.downloadUrl!,
            version: result.latestVersion,
            onProgress: (received, total) {
              if (total > 0) {
                state = UpdateInstallState(
                  phase: UpdateInstallPhase.downloading,
                  progress: received / total,
                );
              }
            },
          );
      state = UpdateInstallState(phase: UpdateInstallPhase.ready, file: file);
      return true;
    } on Object {
      state = const UpdateInstallState(phase: UpdateInstallPhase.failed);
      return false;
    }
  }

  /// Lanza el instalador ya descargado y cierra la app. El caller debe haber
  /// comprobado justo antes que no hay cambios sin guardar.
  Future<void> launch() async {
    final file = state.file;
    if (state.phase != UpdateInstallPhase.ready || file == null) {
      return;
    }
    await ref.read(updateInstallerProvider).launchAndExit(file);
  }
}

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
