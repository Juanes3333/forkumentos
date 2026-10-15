import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/datasource/data/excel_file_watcher.dart';
import 'package:forkumentos/features/datasource/data/excel_opener.dart';
import 'package:forkumentos/features/datasource/data/managed_xlsx_editor.dart';
import 'package:forkumentos/features/datasource/data/xlsx_column_writer.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';

/// Abre el Excel con la aplicación predeterminada; sustituible en pruebas.
final excelOpenerProvider = Provider<ExcelOpener>((ref) => const ExcelOpener());

/// Crea el observer del Excel gestionado; sustituible en pruebas (tiempos
/// cortos).
final excelFileWatcherFactoryProvider =
    Provider<ExcelFileWatcher Function(String path)>(
      (ref) =>
          (path) => ExcelFileWatcher(filePath: path),
    );

/// Último aviso de sincronización con el Excel (para mostrarlo en una
/// SnackBar). La pantalla lo muestra y lo vuelve a poner en `null`.
final datasourceSyncMessageProvider = StateProvider<String?>((ref) => null);

/// Editor que agrega columnas al Excel gestionado; sustituible en pruebas.
final managedXlsxEditorProvider = Provider<ManagedXlsxEditor>(
  (ref) => const ManagedXlsxEditor(),
);

enum AddColumnStatus { success, locked, unsupported, failed }

/// Resultado de [DatasourceSyncController.addColumn].
final class AddColumnOutcome {
  const AddColumnOutcome.success({
    required int this.columnIndex,
    required bool this.appendedAtEnd,
  }) : status = AddColumnStatus.success,
       message = null;

  const AddColumnOutcome.locked()
    : status = AddColumnStatus.locked,
      columnIndex = null,
      appendedAtEnd = null,
      message = null;

  const AddColumnOutcome.unsupported(String this.message)
    : status = AddColumnStatus.unsupported,
      columnIndex = null,
      appendedAtEnd = null;

  const AddColumnOutcome.failed(String this.message)
    : status = AddColumnStatus.failed,
      columnIndex = null,
      appendedAtEnd = null;

  final AddColumnStatus status;

  /// Posición de la columna nueva (solo con [AddColumnStatus.success]).
  final int? columnIndex;

  /// Si la columna quedó al final y no en la posición pedida.
  final bool? appendedAtEnd;

  /// Texto para el usuario cuando no fue un éxito.
  final String? message;
}

final datasourceSyncControllerProvider = Provider<DatasourceSyncController>(
  DatasourceSyncController.new,
);

/// Sincroniza el proyecto con el Excel gestionado: lo vuelve a leer, recuerda
/// su huella (fecha y tamaño) para detectar cambios al abrir el proyecto y
/// migra los proyectos que apuntaban al archivo original del usuario.
final class DatasourceSyncController {
  DatasourceSyncController(this._ref);

  final Ref _ref;

  /// Vuelve a leer el Excel gestionado y deja el proyecto al día. Es lo que
  /// usan el botón "Refrescar datos", el observer y la comprobación al abrir.
  ///
  /// Debe llamarse fuera del ciclo de actualización del notifier de datasource
  /// (desde un callback de interfaz o tras un `await`): actualizar
  /// `embeddedDatasourcePath` desde dentro lo haría reentrar (ver el
  /// `ponytail:` de `refreshDatasource`).
  Future<DatasourceRefreshResult> refresh() async {
    final externalPath = _project()?.externalPath;
    // La huella se toma antes de leer: si el archivo cambia entre medias, la
    // próxima comprobación lo verá distinto y volverá a leerlo.
    final stat = externalPath != null && File(externalPath).existsSync()
        ? File(externalPath).statSync()
        : null;

    final result = await _ref
        .read(activeDatasourceProvider.notifier)
        .refreshDatasource();

    final projectNotifier = _ref.read(activeProjectProvider.notifier);
    switch (result.status) {
      case DatasourceRefreshStatus.updated:
        final path = _ref
            .read(activeDatasourceProvider)
            .valueOrNull
            ?.sourcePath;
        if (path != null) {
          projectNotifier.setEmbeddedArtifactPaths(datasourcePath: path);
        }
        _recordSynced(stat);
      case DatasourceRefreshStatus.unchanged:
        _recordSynced(stat);
      case DatasourceRefreshStatus.notFound:
      case DatasourceRefreshStatus.error:
        break;
    }
    return result;
  }

  /// Comprobación al abrir un proyecto guardado: migra el Excel a la carpeta
  /// gestionada si hace falta y lo vuelve a leer si cambió desde la última
  /// vez. Deja un aviso en [datasourceSyncMessageProvider] cuando hay algo que
  /// contar.
  Future<void> syncOnOpen() async {
    final project = _project();
    final paths = _ref.read(workspacePathsProvider);
    if (project == null || !project.isSaved || paths == null) {
      return;
    }
    final store = _ref.read(managedDatasourceStoreProvider);
    final folder = paths.managedDatasourceFolder(
      projectName: project.name,
      projectId: project.id,
    );

    var external = project.externalPath;
    var migratedTo = '';
    if (external == null || !store.isManaged(external, folder)) {
      // Proyecto anterior a la carpeta gestionada: su Excel es el archivo
      // original del usuario (o, si ya no está, la copia embebida).
      final source = <String?>[
        external,
        project.embeddedPath,
      ].nonNulls.where((path) => File(path).existsSync()).firstOrNull;
      if (source != null) {
        try {
          external = await store.adopt(sourcePath: source, folder: folder);
          _ref
              .read(activeProjectProvider.notifier)
              .setDatasourceExternalPath(external);
          migratedTo = external;
        } on FileSystemException catch (error, stackTrace) {
          _ref
              .read(loggingServiceProvider)
              .error(
                'No se pudo mover el Excel a la carpeta del proyecto',
                module: 'Datasource',
                error: error,
                stackTrace: stackTrace,
              );
          return;
        }
      }
    }
    if (external == null || !File(external).existsSync()) {
      return;
    }

    final current = _project();
    final stat = File(external).statSync();
    final unchanged =
        current?.syncedMtimeMs == stat.modified.millisecondsSinceEpoch &&
        current?.syncedSizeBytes == stat.size;
    if (unchanged && migratedTo.isEmpty) {
      return;
    }

    final result = await refresh();
    final message = migratedTo.isNotEmpty
        ? 'El Excel de este proyecto ahora se guarda en $migratedTo. '
              'Edítalo ahí y Forkumentos se actualizará solo.'
        : describeRefresh(result, whenUnchanged: null);
    if (message != null) {
      _ref.read(datasourceSyncMessageProvider.notifier).state = message;
    }
  }

  /// Agrega la columna [header] al Excel gestionado en la posición
  /// [insertAt] (entre las columnas con encabezado) y vuelve a leerlo.
  ///
  /// Nunca modifica el archivo si algo sale mal: devuelve [AddColumnOutcome]
  /// con la razón (archivo abierto en Excel, libro no soportado, etc.).
  Future<AddColumnOutcome> addColumn({
    required String header,
    required int insertAt,
  }) async {
    final name = header.trim();
    final path = _project()?.externalPath;
    if (name.isEmpty) {
      return const AddColumnOutcome.failed('Escribe un nombre para el campo.');
    }
    if (path == null ||
        !File(path).existsSync() ||
        !path.toLowerCase().endsWith('.xlsx')) {
      return const AddColumnOutcome.unsupported(
        'Solo se pueden crear campos en un Excel .xlsx del proyecto.',
      );
    }
    final headers =
        _ref.read(activeDatasourceProvider).valueOrNull?.headers ??
        const <String>[];
    if (headers.any((h) => h.trim().toLowerCase() == name.toLowerCase())) {
      return const AddColumnOutcome.failed(
        'Ya existe una columna con ese nombre en el Excel.',
      );
    }

    final XlsxColumnInsertResult written;
    try {
      written = await _ref
          .read(managedXlsxEditorProvider)
          .addColumn(path: path, header: name, insertAt: insertAt);
    } on ExcelLockedException {
      return const AddColumnOutcome.locked();
    } on XlsxWriteException catch (error) {
      return AddColumnOutcome.unsupported(error.message);
    } on FileSystemException catch (error, stackTrace) {
      _ref
          .read(loggingServiceProvider)
          .error(
            'No se pudo agregar la columna al Excel',
            module: 'Datasource',
            error: error,
            stackTrace: stackTrace,
          );
      return const AddColumnOutcome.failed(
        'No se pudo escribir en el Excel del proyecto.',
      );
    }

    await refresh();
    return AddColumnOutcome.success(
      columnIndex: written.columnIndex,
      appendedAtEnd: written.appendedAtEnd,
    );
  }

  /// Restaura la copia embebida del proyecto como Excel gestionado en esta
  /// computadora (el proyecto se abrió donde ya no está el archivo, por
  /// ejemplo en otro PC) y lo deja enlazado. Devuelve la ruta del archivo
  /// restaurado, o `null` si no hay copia que restaurar o no se pudo copiar.
  Future<String?> restoreManagedCopy() async {
    final project = _project();
    final paths = _ref.read(workspacePathsProvider);
    final snapshot = project?.embeddedPath;
    if (project == null ||
        paths == null ||
        snapshot == null ||
        !File(snapshot).existsSync()) {
      return null;
    }
    final folder = paths.managedDatasourceFolder(
      projectName: project.name,
      projectId: project.id,
    );
    final String restored;
    try {
      restored = await _ref
          .read(managedDatasourceStoreProvider)
          .adopt(sourcePath: snapshot, folder: folder);
    } on FileSystemException catch (error, stackTrace) {
      _ref
          .read(loggingServiceProvider)
          .error(
            'No se pudo restaurar la copia del Excel',
            module: 'Datasource',
            error: error,
            stackTrace: stackTrace,
          );
      return null;
    }
    _ref.read(activeProjectProvider.notifier)
      ..setDatasourceExternalPath(restored)
      ..setEmbeddedArtifactPaths(datasourcePath: restored);
    // La relectura de la copia recién restaurada deja registrada su huella.
    final result = await refresh();
    if (result.status == DatasourceRefreshStatus.error) {
      return null;
    }
    return restored;
  }

  /// Abre el Excel gestionado con la aplicación predeterminada. Devuelve
  /// `false` si no hay archivo o no se pudo abrir.
  Future<bool> openManagedExcel() async {
    final path = _project()?.externalPath;
    if (path == null || !File(path).existsSync()) {
      return false;
    }
    return _ref.read(excelOpenerProvider).open(path);
  }

  void _recordSynced(FileStat? stat) {
    if (stat == null || stat.type == FileSystemEntityType.notFound) {
      return;
    }
    _ref
        .read(activeProjectProvider.notifier)
        .setDatasourceSyncedStat(
          mtimeMs: stat.modified.millisecondsSinceEpoch,
          sizeBytes: stat.size,
        );
  }

  /// Datos del proyecto activo que se necesitan aquí. Un registro y no el
  /// tipo `Project`: la feature de datasource no importa la de proyecto, solo
  /// lee el proyecto a través del provider compartido.
  _ProjectInfo? _project() {
    final project = _ref.read(activeProjectProvider).valueOrNull;
    if (project == null) {
      return null;
    }
    return (
      id: project.id,
      name: project.name,
      isSaved: project.filePath != null,
      externalPath: project.datasourceExternalPath,
      embeddedPath: project.embeddedDatasourcePath,
      syncedMtimeMs: project.datasourceSyncedMtimeMs,
      syncedSizeBytes: project.datasourceSyncedSizeBytes,
    );
  }
}

typedef _ProjectInfo = ({
  String id,
  String name,
  bool isSaved,
  String? externalPath,
  String? embeddedPath,
  int? syncedMtimeMs,
  int? syncedSizeBytes,
});

/// Texto para el usuario de un resultado de refresco, o [whenUnchanged] si no
/// hubo cambios.
String? describeRefresh(
  DatasourceRefreshResult result, {
  required String? whenUnchanged,
}) {
  return switch (result.status) {
    DatasourceRefreshStatus.unchanged => whenUnchanged,
    DatasourceRefreshStatus.updated => switch (result.rowDelta ?? 0) {
      > 0 => 'Datos actualizados: +${result.rowDelta} filas nuevas',
      < 0 => 'Datos actualizados: ${result.rowDelta} filas',
      _ => 'Datos actualizados',
    },
    DatasourceRefreshStatus.notFound =>
      'El archivo ya no está disponible en su ruta original.',
    DatasourceRefreshStatus.error =>
      result.message ?? 'Ocurrió un error al refrescar la fuente de datos.',
  };
}

/// Mantiene vivo el observer del Excel gestionado y la comprobación al abrir.
/// `App` lo mantiene con `ref.watch`, como `projectActivationListenerProvider`.
final datasourceSyncListenerProvider = Provider<void>((ref) {
  final controller = ref.watch(datasourceSyncControllerProvider);
  ExcelFileWatcher? watcher;
  // Se cancela en stopWatching (al reiniciar el observer o cerrar el
  // provider).
  // ignore: cancel_subscriptions
  StreamSubscription<void>? subscription;
  String? checkedProjectId;

  Future<void> stopWatching() async {
    // Se sueltan las referencias antes de esperar: si no, al reiniciar el
    // observer este cierre (que termina después) cancelaría el nuevo.
    final oldSubscription = subscription;
    final oldWatcher = watcher;
    subscription = null;
    watcher = null;
    await oldSubscription?.cancel();
    await oldWatcher?.dispose();
  }

  void startWatching(String? path) {
    unawaited(stopWatching());
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      return;
    }
    final created = ref.read(excelFileWatcherFactoryProvider)(path);
    watcher = created;
    subscription = created.changes.listen((_) async {
      final result = await controller.refresh();
      final message = describeRefresh(result, whenUnchanged: null);
      if (message != null) {
        ref.read(datasourceSyncMessageProvider.notifier).state = message;
      }
    });
    created.start();
  }

  ref
    ..onDispose(() => unawaited(stopWatching()))
    // Observer: sigue la ruta del Excel gestionado del proyecto activo.
    ..listen<String?>(
      activeProjectProvider.select(
        (state) => state.valueOrNull?.datasourceExternalPath,
      ),
      (previous, next) => startWatching(next),
      fireImmediately: true,
    )
    // Al abrir un proyecto guardado, cuando llega su Excel (la copia
    // embebida), se comprueba si cambió mientras la app estaba cerrada.
    ..listen(activeDatasourceProvider, (previous, next) {
      final project = ref.read(activeProjectProvider).valueOrNull;
      if (project == null ||
          next.valueOrNull == null ||
          project.id == checkedProjectId) {
        return;
      }
      checkedProjectId = project.id;
      unawaited(controller.syncOnOpen());
    });
});
