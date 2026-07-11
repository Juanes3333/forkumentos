import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/routing/app_phase_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../support/fakes.dart';

void main() {
  test('appPhase es landing sin proyecto', () {
    final container = _buildContainer();
    addTearDown(container.dispose);

    expect(container.read(appPhaseProvider), AppPhase.landing);
  });

  test('crear proyecto entra en wizard, no en workbench', () async {
    final container = _buildContainer();
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Demo');

    expect(container.read(appPhaseProvider), AppPhase.wizard);
    expect(container.read(workbenchEnteredProvider), isFalse);
  });

  test('enterWorkbench pasa a workbench solo con proyecto', () async {
    final container = _buildContainer();
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Demo');
    container.read(workbenchEnteredProvider.notifier).enterWorkbench();

    expect(container.read(appPhaseProvider), AppPhase.workbench);
  });

  test('closeProject vuelve a landing y resetea workbenchEntered', () async {
    final container = _buildContainer();
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Demo');
    container.read(workbenchEnteredProvider.notifier).enterWorkbench();
    await container.read(activeProjectProvider.notifier).closeProject();

    expect(container.read(appPhaseProvider), AppPhase.landing);
    expect(container.read(workbenchEnteredProvider), isFalse);
  });
}

ProviderContainer _buildContainer() {
  return ProviderContainer(
    overrides: <Override>[
      loggingServiceProvider.overrideWithValue(FakeLoggingService()),
      projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
    ],
  );
}

final class _FakeProjectRepository implements ProjectRepository {
  @override
  Future<Project> load(
    String filePath, {
    required String cacheDirectory,
  }) async {
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
    String? templateSourcePath,
    String? datasourceSourcePath,
    String? cacheDirectory,
  }) async {
    return project.copyWith(
      filePath: filePath,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
