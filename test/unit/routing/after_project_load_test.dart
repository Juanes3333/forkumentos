import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/storage/storage_providers.dart';
import 'package:forkumentos/core/workspace/workspace_paths.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';
import 'package:forkumentos/routing/after_project_load.dart';
import 'package:forkumentos/routing/app_phase_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';

import '../../support/fakes.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('forkumentos_apl_');
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  ProviderContainer buildContainer({Project? loadResult}) {
    final container = ProviderContainer(
      overrides: <Override>[
        loggingServiceProvider.overrideWithValue(FakeLoggingService()),
        keyValueStorageProvider.overrideWithValue(FakeKeyValueStorage()),
        workspacePathsProvider.overrideWithValue(
          WorkspacePaths(root: tempDirectory.path),
        ),
        projectRepositoryProvider.overrideWithValue(
          _FakeProjectRepository(loadResult: loadResult),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Same keep-alive that App holds.
    container.read(projectActivationListenerProvider);
    return container;
  }

  test('cargar un .fork lo registra en recientes', () async {
    final container = buildContainer();
    await container.read(recentProjectsProvider.future);

    await container
        .read(activeProjectProvider.notifier)
        .loadProject(filePath: '/tmp/modelo-contrato.fork');
    await container.pump();

    final recent =
        container.read(recentProjectsProvider).valueOrNull ?? const [];
    expect(
      recent.map((e) => e.filePath),
      contains('/tmp/modelo-contrato.fork'),
    );
  });

  test('crear un proyecto NO lo registra en recientes', () async {
    final container = buildContainer();
    await container.read(recentProjectsProvider.future);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Nuevo');
    await container.pump();

    expect(container.read(recentProjectsProvider).valueOrNull, isEmpty);
  });

  test('un .fork con ambos recursos embebidos entra al workbench', () async {
    final container = buildContainer(
      loadResult: Project(
        id: 'con-recursos',
        name: 'Con Recursos',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        filePath: '/tmp/con-recursos.fork',
        embeddedTemplatePath: '/tmp/cache/plantilla.docx',
        embeddedDatasourcePath: '/tmp/cache/datos.xlsx',
      ),
    );
    await container.read(recentProjectsProvider.future);

    await container
        .read(activeProjectProvider.notifier)
        .loadProject(filePath: '/tmp/con-recursos.fork');
    await container.pump();

    expect(container.read(workbenchEnteredProvider), isTrue);
    expect(container.read(appPhaseProvider), AppPhase.workbench);
  });

  test('un .fork sin recursos embebidos se queda en el wizard', () async {
    final container = buildContainer();
    await container.read(recentProjectsProvider.future);

    await container
        .read(activeProjectProvider.notifier)
        .loadProject(filePath: '/tmp/solo.fork');
    await container.pump();

    expect(container.read(workbenchEnteredProvider), isFalse);
    expect(container.read(appPhaseProvider), AppPhase.wizard);
  });
}

final class _FakeProjectRepository implements ProjectRepository {
  _FakeProjectRepository({this.loadResult});

  final Project? loadResult;

  @override
  Future<Project> load(
    String filePath, {
    required String cacheDirectory,
  }) async {
    return loadResult ??
        Project(
          id: 'loaded-$filePath',
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
    String? templateSourcePath,
    String? datasourceSourcePath,
    String? cacheDirectory,
  }) async {
    return project.copyWith(filePath: filePath);
  }
}
