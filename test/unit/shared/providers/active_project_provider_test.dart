import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../../support/fakes.dart';

void main() {
  test('createProject crea proyecto activo sin filePath', () async {
    final fakeRepository = FakeProjectRepository();
    final container = _createContainer(fakeRepository);
    addTearDown(container.dispose);

    final notifier = container.read(activeProjectProvider.notifier);
    await notifier.createProject(name: 'Proyecto Nuevo');

    final project = container.read(activeProjectProvider).valueOrNull;
    expect(project, isNotNull);
    expect(project?.name, 'Proyecto Nuevo');
    expect(project?.filePath, isNull);
    expect(project?.id, isNotEmpty);
    expect(project?.createdAt.isUtc, isTrue);
    expect(project?.updatedAt.isUtc, isTrue);
    expect(project?.isDirty, isTrue);
  });

  test('saveProject persiste y actualiza ruta de proyecto', () async {
    final fakeRepository = FakeProjectRepository();
    final container = _createContainer(fakeRepository);
    addTearDown(container.dispose);

    final notifier = container.read(activeProjectProvider.notifier);
    await notifier.createProject(name: 'Proyecto Guardable');
    await notifier.saveProject(
      filePath: '/tmp/proyecto_guardable.forkumentos.json',
    );

    final project = container.read(activeProjectProvider).valueOrNull;
    expect(project, isNotNull);
    expect(project?.filePath, '/tmp/proyecto_guardable.forkumentos.json');
    expect(project?.isDirty, isFalse);
  });

  test('loadProject transiciona loading y luego data', () async {
    final fakeRepository = FakeProjectRepository(
      loadHandler: (String filePath) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return Project(
          id: 'loaded-id',
          name: 'Proyecto Cargado',
          createdAt: DateTime.utc(2026, 2),
          updatedAt: DateTime.utc(2026, 2),
          filePath: filePath,
        );
      },
    );
    final container = _createContainer(fakeRepository);
    addTearDown(container.dispose);

    final notifier = container.read(activeProjectProvider.notifier);
    final emittedStates = <AsyncValue<Project?>>[];
    final subscription = container.listen<AsyncValue<Project?>>(
      activeProjectProvider,
      (_, AsyncValue<Project?> next) {
        emittedStates.add(next);
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await notifier.loadProject(
      filePath: '/tmp/proyecto_cargado.forkumentos.json',
    );

    expect(emittedStates.any((state) => state.isLoading), isTrue);

    final state = container.read(activeProjectProvider);
    expect(state.hasValue, isTrue);
    expect(state.valueOrNull?.name, 'Proyecto Cargado');
    expect(state.valueOrNull?.isDirty, isFalse);
  });

  test('markProjectDirty marca el proyecto activo como sin guardar', () async {
    final fakeRepository = FakeProjectRepository();
    final container = _createContainer(fakeRepository);
    addTearDown(container.dispose);

    final notifier = container.read(activeProjectProvider.notifier);
    await notifier.createProject(name: 'Proyecto Marcable');
    await notifier.saveProject(filePath: '/tmp/marcable.forkumentos.json');
    expect(container.read(activeProjectProvider).valueOrNull?.isDirty, isFalse);

    await notifier.markProjectDirty();

    expect(container.read(activeProjectProvider).valueOrNull?.isDirty, isTrue);
  });

  test('markProjectDirty no hace nada sin proyecto activo', () async {
    final fakeRepository = FakeProjectRepository();
    final container = _createContainer(fakeRepository);
    addTearDown(container.dispose);

    final notifier = container.read(activeProjectProvider.notifier);
    await notifier.markProjectDirty();

    expect(container.read(activeProjectProvider).valueOrNull, isNull);
  });

  test(
    'loadProject fallido pasa a error y dismiss vuelve a no proyecto',
    () async {
      final fakeRepository = FakeProjectRepository(
        loadHandler: (_) async => throw const FormatException('json inválido'),
      );
      final container = _createContainer(fakeRepository);
      addTearDown(container.dispose);

      final notifier = container.read(activeProjectProvider.notifier);
      await notifier.loadProject(filePath: '/tmp/invalido.forkumentos.json');

      final failedState = container.read(activeProjectProvider);
      expect(failedState.hasError, isTrue);
      expect(failedState.error, isA<ProjectLifecycleException>());

      notifier.dismissError();

      final restoredState = container.read(activeProjectProvider);
      expect(restoredState.hasError, isFalse);
      expect(restoredState.valueOrNull, isNull);
    },
  );

  test(
    'saveProject fallido pasa a error y dismiss restaura proyecto activo',
    () async {
      final fakeRepository = FakeProjectRepository(
        saveHandler:
            ({required Project project, required String filePath}) async {
              throw const FileSystemException('denegado');
            },
      );
      final container = _createContainer(fakeRepository);
      addTearDown(container.dispose);

      final notifier = container.read(activeProjectProvider.notifier);
      await notifier.createProject(name: 'Proyecto con Error');
      final beforeSaveFailure = container
          .read(activeProjectProvider)
          .valueOrNull;

      await notifier.saveProject(filePath: '/tmp/denegado.forkumentos.json');

      final failedState = container.read(activeProjectProvider);
      expect(failedState.hasError, isTrue);
      expect(failedState.error, isA<ProjectLifecycleException>());

      notifier.dismissError();

      final restoredProject = container.read(activeProjectProvider).valueOrNull;
      expect(restoredProject?.id, beforeSaveFailure?.id);
      expect(restoredProject?.name, beforeSaveFailure?.name);
    },
  );

  test('closeProject limpia completamente el estado', () async {
    final fakeRepository = FakeProjectRepository();
    final container = _createContainer(fakeRepository);
    addTearDown(container.dispose);

    final notifier = container.read(activeProjectProvider.notifier);
    await notifier.createProject(name: 'Proyecto a Cerrar');

    await notifier.closeProject();

    final state = container.read(activeProjectProvider);
    expect(state.hasError, isFalse);
    expect(state.valueOrNull, isNull);
  });
}

ProviderContainer _createContainer(ProjectRepository repository) {
  return ProviderContainer(
    overrides: <Override>[
      loggingServiceProvider.overrideWithValue(FakeLoggingService()),
      projectRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

final class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository({this.loadHandler, this.saveHandler});

  final Future<Project> Function(String filePath)? loadHandler;
  final Future<Project> Function({
    required Project project,
    required String filePath,
  })?
  saveHandler;

  @override
  Future<Project> load(String filePath) async {
    final handler = loadHandler;
    if (handler != null) {
      return handler(filePath);
    }

    return Project(
      id: 'default-loaded-id',
      name: 'Proyecto Cargado',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      filePath: filePath,
    );
  }

  @override
  Future<Project> save({
    required Project project,
    required String filePath,
  }) async {
    final handler = saveHandler;
    if (handler != null) {
      return handler(project: project, filePath: filePath);
    }

    return project.copyWith(
      filePath: filePath,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
