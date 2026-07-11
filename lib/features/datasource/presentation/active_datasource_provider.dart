import 'dart:async';
import 'dart:io';

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

final class ActiveDatasourceNotifier extends AsyncNotifier<Datasource?> {
  Datasource? _datasourceOnErrorDismiss;

  int _operationToken = 0;

  @override
  FutureOr<Datasource?> build() {
    ref
      ..listen<(String?, String?)>(
        activeProjectProvider.select(
          (state) => (
            state.valueOrNull?.id,
            state.valueOrNull?.embeddedDatasourcePath,
          ),
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
      )
      ..watch(
        activeProjectProvider.select(
          (state) => (
            state.valueOrNull?.id,
            state.valueOrNull?.embeddedDatasourcePath,
          ),
        ),
      );
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
