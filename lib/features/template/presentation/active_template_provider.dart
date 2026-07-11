import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/logging/logging_service.dart';
import 'package:forkumentos/features/template/data/template_repository_provider.dart';
import 'package:forkumentos/features/template/domain/template.dart';
import 'package:forkumentos/features/template/domain/template_repository.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

final activeTemplateProvider =
    AsyncNotifierProvider<ActiveTemplateNotifier, Template?>(
      ActiveTemplateNotifier.new,
    );

final class ActiveTemplateNotifier extends AsyncNotifier<Template?> {
  Template? _templateOnErrorDismiss;

  // Invalidates in-flight `importTemplate` calls whenever the active project
  // changes/closes or a newer operation starts, so a slow load can never be
  // applied after it's no longer relevant (out-of-order completion or a
  // project switch while awaiting `_repository.load`).
  int _operationToken = 0;

  @override
  FutureOr<Template?> build() {
    ref
      ..listen<(String?, String?)>(
        activeProjectProvider.select(
          (state) =>
              (state.valueOrNull?.id, state.valueOrNull?.embeddedTemplatePath),
        ),
        (previous, next) {
          final previousId = previous?.$1;
          final nextId = next.$1;
          final nextPath = next.$2;

          if (previousId == nextId && previous?.$2 == nextPath) {
            return;
          }

          _operationToken++;
          final hadTemplate = state.valueOrNull != null;
          _templateOnErrorDismiss = null;
          state = const AsyncData(null);

          if (hadTemplate) {
            _logger.info(
              'Plantilla activa limpiada por cambio de proyecto.',
              module: 'Template',
            );
          }

          if (nextId != null &&
              nextPath != null &&
              nextPath.isNotEmpty &&
              state.valueOrNull?.sourcePath != nextPath) {
            unawaited(importTemplate(filePath: nextPath));
          }
        },
      )
      ..watch(
        activeProjectProvider.select(
          (state) =>
              (state.valueOrNull?.id, state.valueOrNull?.embeddedTemplatePath),
        ),
      );
    return null;
  }

  Future<void> importTemplate({required String filePath}) async {
    final operationToken = ++_operationToken;
    final previousState = state;
    final previousTemplate = previousState.valueOrNull;
    state = const AsyncLoading<Template?>().copyWithPrevious(previousState);

    try {
      _logger.info('Importando plantilla desde $filePath', module: 'Template');
      final template = await _repository.load(filePath);
      if (operationToken != _operationToken) {
        return;
      }

      _templateOnErrorDismiss = null;
      state = AsyncData(template);
      _logger.info(
        'Plantilla importada: ${template.fileName}',
        module: 'Template',
      );
    } catch (error, stackTrace) {
      if (operationToken != _operationToken) {
        return;
      }

      _logger.error(
        'Fallo al importar plantilla',
        module: 'Template',
        error: error,
        stackTrace: stackTrace,
      );
      _templateOnErrorDismiss = previousTemplate;
      state = AsyncError<Template?>(
        _classifyImportFailure(error),
        stackTrace,
      ).copyWithPrevious(AsyncData(previousTemplate));
    }
  }

  Future<void> removeTemplate() async {
    _operationToken++;
    final previousTemplate = state.valueOrNull;
    _templateOnErrorDismiss = null;
    state = const AsyncData(null);

    if (previousTemplate != null) {
      _logger.info(
        'Plantilla removida: ${previousTemplate.fileName}',
        module: 'Template',
      );
    } else {
      _logger.info('Plantilla removida', module: 'Template');
    }
  }

  void dismissError() {
    final currentState = state;
    if (!currentState.hasError) {
      return;
    }

    final restoredTemplate = _templateOnErrorDismiss;
    _templateOnErrorDismiss = null;
    state = AsyncData(restoredTemplate);
  }

  TemplateRepository get _repository => ref.read(templateRepositoryProvider);

  LoggingService get _logger => ref.read(loggingServiceProvider);

  TemplateLifecycleException _classifyImportFailure(Object error) {
    if (error is FormatException || error is TypeError) {
      final rawMessage = error is FormatException ? error.message : null;
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        return TemplateLifecycleException(rawMessage);
      }

      return const TemplateLifecycleException(
        'El archivo no tiene un formato DOCX válido.',
      );
    }

    if (error is FileSystemException) {
      return const TemplateLifecycleException(
        'No se pudo leer el archivo de plantilla seleccionado.',
      );
    }

    return const TemplateLifecycleException(
      'No se pudo importar la plantilla. Inténtalo nuevamente.',
    );
  }
}

final class TemplateLifecycleException implements Exception {
  const TemplateLifecycleException(this.message);

  final String message;

  @override
  String toString() => message;
}
