import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/app/app.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/document_viewer/data/document_repository_provider.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/project/presentation/project_welcome_screen.dart';
import 'package:forkumentos/features/template/data/template_repository_provider.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/app_phase_provider.dart';
import 'package:forkumentos/routing/app_shell.dart';
import 'package:forkumentos/routing/project_wizard_screen.dart';
import 'package:forkumentos/routing/workbench/workbench_inspector.dart';
import 'package:forkumentos/routing/workbench/workbench_ribbon.dart';
import 'package:forkumentos/routing/workbench/workbench_screen.dart';
import 'package:forkumentos/routing/workbench/workbench_status_bar.dart';
import 'package:forkumentos/routing/workbench/workbench_tab.dart';
import 'package:forkumentos/routing/workbench/workbench_tab_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_workspace.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../support/fakes.dart';

void main() {
  testWidgets('landing no instancia chrome del workbench', (
    WidgetTester tester,
  ) async {
    final container = _buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(ProjectWelcomeScreen), findsOneWidget);
    expect(find.byType(WorkbenchRibbon), findsNothing);
    expect(find.byType(WorkbenchStatusBar), findsNothing);
    expect(find.byType(WorkbenchInspector), findsNothing);
    expect(find.byType(WorkbenchWorkspace), findsNothing);
    expect(find.byType(WorkbenchScreen), findsNothing);
    expect(find.text('Archivo'), findsNothing);
  });

  testWidgets('crear proyecto navega al wizard sin chrome workbench', (
    WidgetTester tester,
  ) async {
    final container = _buildContainer();
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Wizard');

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProjectWizardScreen), findsOneWidget);
    expect(find.text('Proyecto Wizard'), findsOneWidget);
    expect(find.text('Empezar a trabajar'), findsOneWidget);
    expect(find.byType(WorkbenchRibbon), findsNothing);
    expect(find.byType(WorkbenchStatusBar), findsNothing);
    expect(find.byType(WorkbenchInspector), findsNothing);
    expect(find.byType(WorkbenchScreen), findsNothing);
  });

  testWidgets('Empezar a trabajar deshabilitado sin ambos recursos', (
    WidgetTester tester,
  ) async {
    final container = _buildContainer();
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Wizard');

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Empezar a trabajar'),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('Empezar a trabajar entra al workbench con ambos recursos', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = _buildContainer();
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Workbench');
    await container
        .read(activeTemplateProvider.notifier)
        .importTemplate(filePath: '/tmp/plantilla.docx');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/clientes.csv');

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Empezar a trabajar'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkbenchScreen), findsOneWidget);
    expect(find.byType(WorkbenchRibbon), findsOneWidget);
    expect(find.byType(WorkbenchWorkspace), findsOneWidget);
    expect(find.byType(WorkbenchInspector), findsOneWidget);
    expect(find.byType(WorkbenchStatusBar), findsOneWidget);
    expect(find.byType(ProjectWizardScreen), findsNothing);
    expect(container.read(appPhaseProvider), AppPhase.workbench);
  });

  testWidgets('cerrar proyecto destruye workbench y vuelve a landing', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = _buildContainer();
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Cerrar');
    // Fresh create is dirty; mark saved path so close without dialog path
    // is exercised via notifier close after entering workbench.
    container.read(workbenchEnteredProvider.notifier).enterWorkbench();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WorkbenchScreen), findsOneWidget);

    await container.read(activeProjectProvider.notifier).closeProject();
    await tester.pumpAndSettle();

    expect(find.byType(ProjectWelcomeScreen), findsOneWidget);
    expect(find.byType(WorkbenchScreen), findsNothing);
    expect(find.byType(WorkbenchRibbon), findsNothing);
    expect(container.read(appPhaseProvider), AppPhase.landing);
  });

  testWidgets('cambiar pestaña del ribbon mantiene el inspector de campos', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = _buildContainer();
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Workbench');
    container.read(workbenchEnteredProvider.notifier).enterWorkbench();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plantillas'));
    await tester.pumpAndSettle();

    expect(find.text('Campos'), findsOneWidget);
    expect(container.read(workbenchTabProvider), WorkbenchTab.templates);
  });

  testWidgets('documento permanece visible al cambiar pestañas', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = _buildContainer();
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Workbench');
    await container
        .read(activeTemplateProvider.notifier)
        .importTemplate(filePath: '/tmp/plantilla.docx');
    container.read(workbenchEnteredProvider.notifier).enterWorkbench();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Documento de ejemplo', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Plantillas'));
    await tester.pumpAndSettle();

    expect(container.read(workbenchTabProvider), WorkbenchTab.templates);
    expect(find.text('Campos'), findsOneWidget);
    expect(
      find.text('Documento de ejemplo', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    expect(
      find.text('Documento de ejemplo', findRichText: true),
      findsOneWidget,
    );
  });
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
