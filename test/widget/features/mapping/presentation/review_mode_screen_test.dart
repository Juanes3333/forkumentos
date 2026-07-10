import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/document_viewer/data/document_repository_provider.dart';
import 'package:forkumentos/features/mapping/domain/mapping_review.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_provider.dart';
import 'package:forkumentos/features/mapping/presentation/review_mode_screen.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/template/data/template_repository_provider.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../../../support/fakes.dart';

void main() {
  testWidgets('muestra panel de revisión con resumen y export bloqueado', (
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
        mappingReviewProvider.overrideWith((ref) {
          final assignments = ref
              .watch(activeMappingProvider)
              .state
              .assignments;
          if (assignments.isEmpty) {
            return null;
          }

          return buildMappingReviewSnapshot(
            assignments: assignments,
            datasourceHeaders: <String>['nombre', 'correo'],
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Review');
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ReviewModeScreen(
            documentPath: '/tmp/plantilla.docx',
            headers: <String>['nombre', 'correo'],
            previewRow: <String?>['Ana', 'ana@example.com'],
            isSourceLoading: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Revisión de mapeo'), findsOneWidget);
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('Estadísticas'), findsOneWidget);
    expect(find.text('Exportar'), findsOneWidget);
    expect(
      find.text('Exportación bloqueada hasta resolver los problemas'),
      findsOneWidget,
    );
    expect(find.text('Campos sin asignar (1)'), findsOneWidget);
    expect(find.text('correo'), findsWidgets);
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
