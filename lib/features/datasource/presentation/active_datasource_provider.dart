import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/logging/logging_service.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/domain/datasource_repository.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

final activeDatasourceProvider =
    AsyncNotifierProvider<ActiveDatasourceNotifier, Datasource?>(
      ActiveDatasourceNotifier.new,
    );

/// `true` only when the active project has a `datasourceExternalPath` and
/// that path still exists on this machine — the UI's sole source of truth
/// for whether "Refrescar datos" should be enabled.
final datasourceRefreshAvailableProvider = Provider<bool>((ref) {
  final externalPath = ref.watch(
    activeProjectProvider.select(
      (state) => state.valueOrNull?.datasourceExternalPath,
    ),
  );
  if (externalPath == null || externalPath.isEmpty) {
    return false;
  }
  return File(externalPath).existsSync();
});

enum DatasourceRefreshStatus { unchanged, updated, notFound, error }

/// Result of [ActiveDatasourceNotifier.refreshDatasource].
///
/// [rowDelta] is only meaningful when [status] is
/// [DatasourceRefreshStatus.updated]: `newRowCount - oldRowCount` (can be
/// negative if rows were removed from the source file). [message] is only
/// meaningful when [status] is [DatasourceRefreshStatus.error] — an
/// already-user-facing string (never a raw exception), mirroring
/// [DatasourceLifecycleException.message].
final class DatasourceRefreshResult {
  const DatasourceRefreshResult._(this.status, {this.rowDelta, this.message});

  const DatasourceRefreshResult.unchanged()
    : this._(DatasourceRefreshStatus.unchanged);

  const DatasourceRefreshResult.updated({required int rowDelta})
    : this._(DatasourceRefreshStatus.updated, rowDelta: rowDelta);

  const DatasourceRefreshResult.notFound()
    : this._(DatasourceRefreshStatus.notFound);

  const DatasourceRefreshResult.error(String message)
    : this._(DatasourceRefreshStatus.error, message: message);

  final DatasourceRefreshStatus status;
  final int? rowDelta;
  final String? message;
}

final class ActiveDatasourceNotifier extends AsyncNotifier<Datasource?> {
  Datasource? _datasourceOnErrorDismiss;

  int _operationToken = 0;

  @override
  FutureOr<Datasource?> build() {
    // Deliberately `listen` only, not `watch`, on activeProjectProvider.
    // `watch` would make Riverpod mark *this* element as having an outdated
    // dependency the instant activeProjectProvider changes, and it does so
    // before running the `listen` callback below. Since that callback calls
    // `ref.read` (via importDatasource -> _logger/_repository) synchronously,
    // that combination trips Riverpod's `_assertNotOutdated`: "Cannot use
    // ref functions after the dependency of a provider changed but before
    // the provider rebuilt". `listen` alone still subscribes this provider
    // to every change (nothing here needs `build()` itself to rerun — state
    // is managed by hand in the callback), without ever flagging this
    // element outdated. See active_datasource_provider_test.dart's
    // reentrancy regression test.
    ref.listen<(String?, String?)>(
      activeProjectProvider.select(
        (state) =>
            (state.valueOrNull?.id, state.valueOrNull?.embeddedDatasourcePath),
      ),
      (previous, next) {
        final previousId = previous?.$1;
        final nextId = next.$1;
        final nextPath = next.$2;

        if (previousId == nextId && previous?.$2 == nextPath) {
          return;
        }

        _operationToken++;
        final hadDatasource = state.valueOrNull != null;
        _datasourceOnErrorDismiss = null;
        state = const AsyncData(null);

        if (hadDatasource) {
          _logger.info(
            'Fuente de datos activa limpiada por cambio de proyecto.',
            module: 'Datasource',
          );
        }

        if (nextId != null &&
            nextPath != null &&
            nextPath.isNotEmpty &&
            state.valueOrNull?.sourcePath != nextPath) {
          unawaited(importDatasource(filePath: nextPath));
        }
      },
    );

    final initialPath = ref.read(
      activeProjectProvider.select(
        (state) => state.valueOrNull?.embeddedDatasourcePath,
      ),
    );
    if (initialPath != null && initialPath.isNotEmpty) {
      return ref.read(datasourceRepositoryProvider).load(initialPath);
    }

    return null;
  }

  Future<void> importDatasource({required String filePath}) async {
    final operationToken = ++_operationToken;
    final previousState = state;
    final previousDatasource = previousState.valueOrNull;
    state = const AsyncLoading<Datasource?>().copyWithPrevious(previousState);

    try {
      _logger.info(
        'Importando fuente de datos desde $filePath',
        module: 'Datasource',
      );
      final datasource = await _repository.load(filePath);
      if (operationToken != _operationToken) {
        return;
      }

      _datasourceOnErrorDismiss = null;
      state = AsyncData(datasource);
      _logger.info(
        'Fuente de datos importada: ${datasource.fileName}',
        module: 'Datasource',
      );
    } catch (error, stackTrace) {
      if (operationToken != _operationToken) {
        return;
      }

      _logger.error(
        'Fallo al importar fuente de datos',
        module: 'Datasource',
        error: error,
        stackTrace: stackTrace,
      );
      _datasourceOnErrorDismiss = previousDatasource;
      state = AsyncError<Datasource?>(
        _classifyImportFailure(error),
        stackTrace,
      ).copyWithPrevious(AsyncData(previousDatasource));
    }
  }

  /// Re-reads the datasource from `Project.datasourceExternalPath` (the
  /// original file the user picked, as opposed to the cached copy embedded
  /// in the `.fork`) and reconciles it against the currently active
  /// datasource.
  ///
  /// Never destructive: a missing/absent path or an unchanged file leaves
  /// the active datasource untouched. Only an actual content change updates
  /// state — the caller is responsible for re-syncing
  /// `Project.embeddedDatasourcePath` afterwards (see the `ponytail:` note
  /// below for why this method cannot safely do that itself).
  Future<DatasourceRefreshResult> refreshDatasource() async {
    final externalPath = ref.read(
      activeProjectProvider.select(
        (state) => state.valueOrNull?.datasourceExternalPath,
      ),
    );
    if (externalPath == null ||
        externalPath.isEmpty ||
        !File(externalPath).existsSync()) {
      return const DatasourceRefreshResult.notFound();
    }

    final operationToken = ++_operationToken;
    final previousState = state;
    final previousDatasource = previousState.valueOrNull;
    state = const AsyncLoading<Datasource?>().copyWithPrevious(previousState);

    try {
      _logger.info(
        'Refrescando fuente de datos desde $externalPath',
        module: 'Datasource',
      );
      final refreshed = await _repository.load(externalPath);
      if (operationToken != _operationToken) {
        return const DatasourceRefreshResult.unchanged();
      }

      if (previousDatasource != null &&
          _hasSameContent(previousDatasource, refreshed)) {
        state = AsyncData(previousDatasource);
        return const DatasourceRefreshResult.unchanged();
      }

      _datasourceOnErrorDismiss = null;
      state = AsyncData(refreshed);
      // ponytail: NOT syncing Project.embeddedDatasourcePath here on
      // purpose. This notifier both `watch`es and mutates
      // activeProjectProvider (see build()); doing that mutation
      // synchronously (or even via a microtask) from inside this method
      // re-enters this same provider mid-update and Riverpod's
      // `_assertNotOutdated` rejects it (reproduced in
      // active_datasource_provider_test.dart during development). The
      // existing embeddedDatasourcePath sync after importDatasource
      // (`_syncEmbeddedDatasourcePath` in datasource_resource_card.dart)
      // runs safely because it fires from a widget callback *after*
      // importDatasource's Future has fully resolved, outside this
      // notifier's own update cycle. The caller (UI) MUST do the same
      // here: after `await refreshDatasource()` returns `updated`, call
      // `activeProjectProvider.notifier.setEmbeddedArtifactPaths(
      // datasourcePath: refreshed.sourcePath)` using
      // `activeDatasourceProvider`'s new `sourcePath`, exactly mirroring
      // `_syncEmbeddedDatasourcePath`.
      _logger.info(
        'Fuente de datos refrescada: ${refreshed.fileName}',
        module: 'Datasource',
      );
      return DatasourceRefreshResult.updated(
        rowDelta: refreshed.rowCount - (previousDatasource?.rowCount ?? 0),
      );
    } catch (error, stackTrace) {
      if (operationToken != _operationToken) {
        return const DatasourceRefreshResult.unchanged();
      }

      _logger.error(
        'Fallo al refrescar fuente de datos',
        module: 'Datasource',
        error: error,
        stackTrace: stackTrace,
      );
      final classified = _classifyImportFailure(error);
      _datasourceOnErrorDismiss = previousDatasource;
      state = AsyncError<Datasource?>(
        classified,
        stackTrace,
      ).copyWithPrevious(AsyncData(previousDatasource));
      return DatasourceRefreshResult.error(classified.message);
    }
  }

  // ponytail: content identity is approximated from headers/rowCount/
  // fileSizeBytes/previewRow since DatasourceRepository doesn't expose a
  // byte hash or full row content. Good enough to distinguish "unchanged"
  // from "changed" for the refresh button; upgrade to a real content hash
  // if a false "unchanged" (same shape, edited values) becomes a problem.
  bool _hasSameContent(Datasource a, Datasource b) {
    const listEquals = ListEquality<Object?>();
    return a.rowCount == b.rowCount &&
        a.fileSizeBytes == b.fileSizeBytes &&
        a.format == b.format &&
        listEquals.equals(a.headers, b.headers) &&
        listEquals.equals(a.previewRow, b.previewRow);
  }

  Future<void> removeDatasource() async {
    _operationToken++;
    final previousDatasource = state.valueOrNull;
    _datasourceOnErrorDismiss = null;
    state = const AsyncData(null);

    if (previousDatasource != null) {
      _logger.info(
        'Fuente de datos removida: ${previousDatasource.fileName}',
        module: 'Datasource',
      );
    } else {
      _logger.info('Fuente de datos removida', module: 'Datasource');
    }
  }

  void dismissError() {
    final currentState = state;
    if (!currentState.hasError) {
      return;
    }

    final restoredDatasource = _datasourceOnErrorDismiss;
    _datasourceOnErrorDismiss = null;
    state = AsyncData(restoredDatasource);
  }

  DatasourceRepository get _repository =>
      ref.read(datasourceRepositoryProvider);

  LoggingService get _logger => ref.read(loggingServiceProvider);

  DatasourceLifecycleException _classifyImportFailure(Object error) {
    if (error is FormatException || error is TypeError) {
      final rawMessage = error is FormatException ? error.message : null;
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        return DatasourceLifecycleException(rawMessage);
      }

      return const DatasourceLifecycleException(
        'El archivo de datos no tiene un formato válido.',
      );
    }

    if (error is FileSystemException) {
      return const DatasourceLifecycleException(
        'No se pudo leer el archivo de datos seleccionado.',
      );
    }

    return const DatasourceLifecycleException(
      'No se pudo importar la fuente de datos. Inténtalo nuevamente.',
    );
  }
}

final class DatasourceLifecycleException implements Exception {
  const DatasourceLifecycleException(this.message);

  final String message;

  @override
  String toString() => message;
}
