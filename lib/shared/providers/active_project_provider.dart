import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/logging/logging_service.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';
import 'package:uuid/uuid.dart';

final activeProjectProvider =
    AsyncNotifierProvider<ActiveProjectNotifier, Project?>(
      ActiveProjectNotifier.new,
    );

final class ActiveProjectNotifier extends AsyncNotifier<Project?> {
  final Uuid _uuid = const Uuid();
  Future<void> _operationQueue = Future<void>.value();
  Project? _projectOnErrorDismiss;

  @override
  FutureOr<Project?> build() {
    return null;
  }

  Future<void> createProject({required String name}) {
    return _enqueueOperation(() async {
      final normalizedName = name.trim();
      if (normalizedName.isEmpty) {
        state = AsyncError<Project?>(
          const ProjectLifecycleException(
            'Ingresa un nombre para crear el proyecto.',
          ),
          StackTrace.current,
        );
        _projectOnErrorDismiss = null;
        return;
      }

      final now = DateTime.now().toUtc();
      final project = Project(
        id: _uuid.v4(),
        name: normalizedName,
        createdAt: now,
        updatedAt: now,
        isDirty: true,
      );

      _logger.info('Proyecto creado: ${project.name}', module: 'Project');
      _projectOnErrorDismiss = null;
      state = AsyncData(project);
    });
  }

  Future<void> saveProject({
    String? filePath,
    String? templateSourcePath,
    String? datasourceSourcePath,
  }) {
    return _enqueueOperation(() async {
      final currentProject = state.valueOrNull;
      if (currentProject == null) {
        return;
      }

      final resolvedFilePath = filePath ?? currentProject.filePath;
      if (resolvedFilePath == null || resolvedFilePath.trim().isEmpty) {
        const failure = ProjectLifecycleException(
          'Selecciona una ubicación para guardar el proyecto.',
        );
        _logger.warning(
          'Guardado cancelado: no se recibió ruta destino',
          module: 'Project',
        );
        _projectOnErrorDismiss = currentProject;
        state = AsyncError<Project?>(
          failure,
          StackTrace.current,
        ).copyWithPrevious(AsyncData(currentProject));
        return;
      }

      try {
        _logger.info(
          'Guardando proyecto en $resolvedFilePath',
          module: 'Project',
        );
        final paths = ref.read(workspacePathsProvider);
        final savedProject = await _repository.save(
          project: currentProject,
          filePath: resolvedFilePath,
          templateSourcePath: templateSourcePath,
          datasourceSourcePath: datasourceSourcePath,
          cacheDirectory: paths?.cache,
        );
        _projectOnErrorDismiss = null;
        state = AsyncData(savedProject.copyWith(isDirty: false));
        _logger.info(
          'Proyecto guardado: ${savedProject.name}',
          module: 'Project',
        );
      } catch (error, stackTrace) {
        _logger.error(
          'Fallo al guardar proyecto',
          module: 'Project',
          error: error,
          stackTrace: stackTrace,
        );
        _projectOnErrorDismiss = currentProject;
        state = AsyncError<Project?>(
          _classifySaveFailure(error),
          stackTrace,
        ).copyWithPrevious(AsyncData(currentProject));
      }
    });
  }

  Future<void> loadProject({required String filePath}) {
    return _enqueueOperation(() async {
      state = const AsyncLoading<Project?>();

      try {
        final paths = ref.read(workspacePathsProvider);
        if (paths == null) {
          throw const ProjectLifecycleException(
            'El directorio de trabajo aún no está disponible.',
          );
        }
        await paths.ensureAll();

        _logger.info('Abriendo proyecto desde $filePath', module: 'Project');
        final project = await _repository.load(
          filePath,
          cacheDirectory: paths.cache,
        );
        _projectOnErrorDismiss = null;
        state = AsyncData(project.copyWith(isDirty: false));
        _logger.info('Proyecto abierto: ${project.name}', module: 'Project');
      } catch (error, stackTrace) {
        _logger.error(
          'Fallo al abrir proyecto',
          module: 'Project',
          error: error,
          stackTrace: stackTrace,
        );
        _projectOnErrorDismiss = null;
        state = AsyncError<Project?>(_classifyLoadFailure(error), stackTrace);
      }
    });
  }

  Future<void> closeProject() {
    return _enqueueOperation(() async {
      final currentProject = state.valueOrNull;
      state = const AsyncLoading<Project?>();
      _logger.info('Cerrando proyecto activo', module: 'Project');

      final paths = ref.read(workspacePathsProvider);
      if (currentProject != null && paths != null) {
        final cacheDir = Directory(paths.projectCache(currentProject.id));
        // ignore: avoid_slow_async_io
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
        }
      }

      _projectOnErrorDismiss = null;
      state = const AsyncData(null);
      _logger.info('Proyecto cerrado', module: 'Project');
    });
  }

  Future<void> markProjectDirty() {
    return _enqueueOperation(() async {
      final currentProject = state.valueOrNull;
      if (currentProject == null) {
        return;
      }

      state = AsyncData(currentProject.copyWith(isDirty: true));
    });
  }

  /// Records artifact paths for portable .fork saves without feature laterals.
  void setEmbeddedArtifactPaths({
    String? templatePath,
    String? datasourcePath,
    bool clearTemplate = false,
    bool clearDatasource = false,
  }) {
    final currentProject = state.valueOrNull;
    if (currentProject == null) {
      return;
    }

    final nextTemplate = clearTemplate
        ? null
        : (templatePath ?? currentProject.embeddedTemplatePath);
    final nextDatasource = clearDatasource
        ? null
        : (datasourcePath ?? currentProject.embeddedDatasourcePath);

    if (nextTemplate == currentProject.embeddedTemplatePath &&
        nextDatasource == currentProject.embeddedDatasourcePath) {
      return;
    }

    state = AsyncData(
      currentProject.copyWith(
        embeddedTemplatePath: nextTemplate,
        embeddedDatasourcePath: nextDatasource,
        isDirty: true,
      ),
    );
  }

  Future<void> updateMappingAssignments(
    List<Map<String, dynamic>> mappingAssignments,
  ) {
    return _enqueueOperation(() async {
      final currentProject = state.valueOrNull;
      if (currentProject == null) {
        return;
      }

      state = AsyncData(
        currentProject.copyWith(
          mappingAssignments: mappingAssignments,
          isDirty: true,
        ),
      );
    });
  }

  void dismissError() {
    final currentState = state;
    if (!currentState.hasError) {
      return;
    }

    final restoredProject = _projectOnErrorDismiss;
    _projectOnErrorDismiss = null;
    state = AsyncData(restoredProject);
  }

  Future<void> _enqueueOperation(Future<void> Function() operation) {
    final queuedOperation = _operationQueue
        .catchError((Object _, StackTrace __) {})
        .then((_) => operation());
    _operationQueue = queuedOperation;
    return queuedOperation;
  }

  ProjectRepository get _repository => ref.read(projectRepositoryProvider);

  LoggingService get _logger => ref.read(loggingServiceProvider);

  ProjectLifecycleException _classifySaveFailure(Object error) {
    if (error is FileSystemException) {
      return const ProjectLifecycleException(
        'No se pudo guardar el proyecto en la ruta seleccionada.',
      );
    }

    return const ProjectLifecycleException(
      'No se pudo guardar el proyecto. Inténtalo nuevamente.',
    );
  }

  ProjectLifecycleException _classifyLoadFailure(Object error) {
    if (error is ProjectLifecycleException) {
      return error;
    }

    if (error is FileSystemException) {
      return const ProjectLifecycleException(
        'No se pudo leer el archivo del proyecto.',
      );
    }

    if (error is FormatException) {
      final message = error.message.trim();
      if (message.isNotEmpty) {
        return ProjectLifecycleException(message);
      }
      return const ProjectLifecycleException(
        'El archivo no tiene un formato de proyecto válido.',
      );
    }

    if (error is TypeError) {
      return const ProjectLifecycleException(
        'El archivo no tiene un formato de proyecto válido.',
      );
    }

    return const ProjectLifecycleException(
      'No se pudo abrir el proyecto. Verifica el archivo e inténtalo de nuevo.',
    );
  }
}

final class ProjectLifecycleException implements Exception {
  const ProjectLifecycleException(this.message);

  final String message;

  @override
  String toString() => message;
}
