import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/app/app.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/project/presentation/project_welcome_screen.dart';
import 'package:forkumentos/features/project/presentation/project_workbench_screen.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../support/fakes.dart';

void main() {
  testWidgets('ruta raíz muestra welcome cuando no hay proyecto activo', (
    WidgetTester tester,
  ) async {
    final container = _buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProjectWelcomeScreen), findsOneWidget);
    expect(find.byType(ProjectWorkbenchScreen), findsNothing);
  });

  testWidgets('ruta raíz redirige a workbench cuando hay proyecto activo', (
    WidgetTester tester,
  ) async {
    final container = _buildContainer();
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Router');

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProjectWorkbenchScreen), findsOneWidget);
    expect(find.byType(ProjectWelcomeScreen), findsNothing);
  });
}

ProviderContainer _buildContainer() {
  return ProviderContainer(
    overrides: <Override>[
      loggingServiceProvider.overrideWithValue(FakeLoggingService()),
      projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
      windowServiceProvider.overrideWithValue(FakeWindowService()),
    ],
  );
}

final class _FakeProjectRepository implements ProjectRepository {
  @override
  Future<Project> load(String filePath) async {
    return Project(
      id: 'project-router',
      name: 'Proyecto Router',
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
    return project.copyWith(
      filePath: filePath,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
