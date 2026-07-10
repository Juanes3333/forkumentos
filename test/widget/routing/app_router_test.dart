import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/app/app.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/document_viewer/data/document_repository_provider.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/project/presentation/project_welcome_screen.dart';
import 'package:forkumentos/features/template/data/template_repository_provider.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_inspector.dart';
import 'package:forkumentos/routing/workbench/workbench_tab.dart';
import 'package:forkumentos/routing/workbench/workbench_tab_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_workspace.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../support/fakes.dart';

void main() {
  testWidgets('workbench muestra bienvenida sin proyecto activo', (
    WidgetTester tester,
  ) async {
    final container = _buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProjectWelcomeScreen), findsOneWidget);
    expect(find.byType(WorkbenchInspector), findsNothing);
    expect(find.text('Archivo'), findsOneWidget);
  });

  testWidgets('workbench muestra workspace e inspector con proyecto', (
    WidgetTester tester,
  ) async {
    final container = _buildContainer();
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Workbench');

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WorkbenchWorkspace), findsOneWidget);
    expect(find.byType(WorkbenchInspector), findsOneWidget);
    expect(find.byType(ProjectWelcomeScreen), findsNothing);
  });

  testWidgets('cambiar pestaña del ribbon mantiene el inspector de preview', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = _buildContainer();
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Workbench');

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plantilla'));
    await tester.pumpAndSettle();

    expect(find.text('Inspector · Preview'), findsOneWidget);
    expect(find.text('Fila activa'), findsOneWidget);
    expect(container.read(workbenchTabProvider), WorkbenchTab.template);
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

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Documento de ejemplo', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Datos'));
    await tester.pumpAndSettle();

    expect(container.read(workbenchTabProvider), WorkbenchTab.datasource);
    expect(find.text('Inspector · Preview'), findsOneWidget);
    expect(
      find.text('Documento de ejemplo', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Mapeo'));
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
