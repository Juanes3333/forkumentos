import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/storage/storage_providers.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/project/presentation/project_welcome_screen.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_screen.dart';
import 'package:forkumentos/routing/workbench/workbench_tab.dart';
import 'package:forkumentos/routing/workbench/workbench_tab_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../../../support/fakes.dart';

void main() {
  testWidgets('ProjectWelcomeScreen muestra acciones de crear y abrir', (
    WidgetTester tester,
  ) async {
    final container = _buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProjectWelcomeScreen()),
      ),
    );

    expect(find.text('Crear proyecto'), findsNWidgets(1));
    expect(find.text('Abrir proyecto'), findsNWidgets(1));
    expect(find.text('Inicia un proyecto'), findsOneWidget);
  });

  testWidgets(
    'ProjectWelcomeScreen muestra estado vacío sin proyectos recientes',
    (WidgetTester tester) async {
      final container = _buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProjectWelcomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin proyectos recientes todavía.'), findsOneWidget);
    },
  );

  testWidgets('ProjectWelcomeScreen renderiza proyectos recientes', (
    WidgetTester tester,
  ) async {
    final container = _buildContainer();
    addTearDown(container.dispose);
    await container.read(recentProjectsProvider.future);
    await container
        .read(recentProjectsProvider.notifier)
        .record(
          filePath: '/tmp/reciente.forkumentos.json',
          name: 'Proyecto Reciente',
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProjectWelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Proyecto Reciente'), findsOneWidget);
    expect(find.text('/tmp/reciente.forkumentos.json'), findsOneWidget);
  });

  testWidgets('Workbench inspector muestra el navegador de campos', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = _buildContainer();
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');
    container.read(workbenchTabProvider.notifier).selectTab(WorkbenchTab.file);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkbenchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Campos'), findsOneWidget);
    expect(find.textContaining('Importa una fuente de datos'), findsOneWidget);
  });
}

ProviderContainer _buildContainer() {
  return ProviderContainer(
    overrides: <Override>[
      loggingServiceProvider.overrideWithValue(FakeLoggingService()),
      projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
      keyValueStorageProvider.overrideWithValue(FakeKeyValueStorage()),
      windowServiceProvider.overrideWithValue(FakeWindowService()),
    ],
  );
}

final class FakeProjectRepository implements ProjectRepository {
  @override
  Future<Project> load(String filePath) async {
    return Project(
      id: 'loaded-id',
      name: 'Proyecto cargado',
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
