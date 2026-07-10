import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/document_viewer/data/document_repository_provider.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_provider.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/template/data/template_repository_provider.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_screen.dart';
import 'package:forkumentos/routing/workbench/workbench_tab.dart';
import 'package:forkumentos/routing/workbench/workbench_tab_provider.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../../../support/fakes.dart';

void main() {
  testWidgets('mantiene la pestaña de revisión con inspector de preview', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: <Override>[
        loggingServiceProvider.overrideWithValue(FakeLoggingService()),
        projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
        templateRepositoryProvider.overrideWithValue(FakeTemplateRepository()),
        datasourceRepositoryProvider.overrideWithValue(
          FakeDatasourceRepository(),
        ),
        documentRepositoryProvider.overrideWithValue(FakeDocumentRepository()),
        windowServiceProvider.overrideWithValue(FakeWindowService()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Review');
    await container
        .read(activeTemplateProvider.notifier)
        .importTemplate(filePath: '/tmp/plantilla.docx');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/clientes.csv');
    container
        .read(activeMappingProvider.notifier)
        .confirmAssignment(
          selection: const DocumentTextSelection(
            path: DocumentTextPath(
              pageIndex: 0,
              steps: <DocumentPathStep>[
                DocumentPathStep.rootBlock(blockIndex: 0),
              ],
            ),
            startOffset: 0,
            endOffset: 3,
            selectedText: 'Ana',
          ),
          fieldHeader: 'nombre',
          fieldIndex: 0,
          headerCount: 2,
        );
    container
        .read(mappingWorkflowProvider.notifier)
        .enterReview(userInitiated: true);
    container
        .read(workbenchTabProvider.notifier)
        .selectTab(WorkbenchTab.review);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkbenchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(workbenchTabProvider), WorkbenchTab.review);
    expect(find.text('Inspector · Preview'), findsOneWidget);
    expect(find.text('Asignaciones'), findsOneWidget);
    expect(find.textContaining('1 región'), findsOneWidget);
    expect(find.text('Fila activa'), findsOneWidget);
  });
}

final class _FakeProjectRepository implements ProjectRepository {
  @override
  Future<Project> load(String filePath) async {
    throw UnimplementedError();
  }

  @override
  Future<Project> save({
    required Project project,
    required String filePath,
  }) async {
    return project;
  }
}
