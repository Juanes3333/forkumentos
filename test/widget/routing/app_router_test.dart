import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/app/app.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/presentation/datasource_management_screen.dart';
import 'package:forkumentos/features/document_viewer/data/document_repository_provider.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_screen.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/project/presentation/project_welcome_screen.dart';
import 'package:forkumentos/features/project/presentation/project_workbench_screen.dart';
import 'package:forkumentos/features/template/data/template_repository_provider.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/features/template/presentation/template_management_screen.dart';
import 'package:forkumentos/routing/app_router.dart';
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

  testWidgets('ruta de plantilla requiere proyecto activo', (
    WidgetTester tester,
  ) async {
    final withoutProjectContainer = _buildContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: withoutProjectContainer,
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    withoutProjectContainer.read(appRouterProvider).go('/project/template');
    await tester.pumpAndSettle();

    expect(find.byType(ProjectWelcomeScreen), findsOneWidget);
    expect(find.byType(TemplateManagementScreen), findsNothing);

    final withProjectContainer = _buildContainer();
    await withProjectContainer
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Router');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: withProjectContainer,
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    withProjectContainer.read(appRouterProvider).go('/project/template');
    await tester.pumpAndSettle();

    expect(find.byType(TemplateManagementScreen), findsOneWidget);
  });

  testWidgets('ruta de datasource requiere proyecto activo', (
    WidgetTester tester,
  ) async {
    final withoutProjectContainer = _buildContainer();
    addTearDown(withoutProjectContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: withoutProjectContainer,
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    withoutProjectContainer.read(appRouterProvider).go('/project/datasource');
    await tester.pumpAndSettle();

    expect(find.byType(ProjectWelcomeScreen), findsOneWidget);
    expect(find.byType(DatasourceManagementScreen), findsNothing);

    final withProjectContainer = _buildContainer();
    addTearDown(withProjectContainer.dispose);
    await withProjectContainer
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Router');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: withProjectContainer,
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    withProjectContainer.read(appRouterProvider).go('/project/datasource');
    await tester.pumpAndSettle();

    expect(find.byType(DatasourceManagementScreen), findsOneWidget);
  });

  testWidgets(
    'ruta de documento requiere proyecto activo y refleja plantilla',
    (WidgetTester tester) async {
      final withoutProjectContainer = _buildContainer();
      addTearDown(withoutProjectContainer.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: withoutProjectContainer,
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      withoutProjectContainer.read(appRouterProvider).go('/project/document');
      await tester.pumpAndSettle();

      expect(find.byType(ProjectWelcomeScreen), findsOneWidget);
      expect(find.byType(DocumentViewerScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
      withoutProjectContainer.dispose();
      await tester.pump();

      final withProjectContainer = _buildContainer();
      addTearDown(withProjectContainer.dispose);
      await withProjectContainer
          .read(activeProjectProvider.notifier)
          .createProject(name: 'Proyecto Router');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: withProjectContainer,
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      withProjectContainer.read(appRouterProvider).go('/project/document');
      await tester.pumpAndSettle();

      expect(find.byType(DocumentViewerScreen), findsOneWidget);
      expect(
        find.text(
          'Todavía no importaste una plantilla DOCX para este proyecto.',
        ),
        findsOneWidget,
      );

      await withProjectContainer
          .read(activeTemplateProvider.notifier)
          .importTemplate(filePath: '/tmp/plantilla.docx');
      await tester.pumpAndSettle();

      expect(
        find.text('Documento de ejemplo', findRichText: true),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
      withProjectContainer.dispose();
      await tester.pump();
    },
  );
}

ProviderContainer _buildContainer() {
  return ProviderContainer(
    overrides: <Override>[
      loggingServiceProvider.overrideWithValue(FakeLoggingService()),
      projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
      datasourceRepositoryProvider.overrideWithValue(
        FakeDatasourceRepository(),
      ),
      templateRepositoryProvider.overrideWithValue(FakeTemplateRepository()),
      documentRepositoryProvider.overrideWithValue(FakeDocumentRepository()),
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
