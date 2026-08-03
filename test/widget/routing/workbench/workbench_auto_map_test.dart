import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/app/app.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/template/data/template_repository_provider.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/app_phase_provider.dart';
import 'package:forkumentos/shared/data/document_repository_provider.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../../support/fakes.dart';

void main() {
  testWidgets('Auto-mapear está deshabilitado sin fuente ni documento', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = _buildContainer();
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Sin Recursos');
    container.read(workbenchEnteredProvider.notifier).enterWorkbench();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Auto-mapear'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Auto-mapear asigna las columnas y confirma con un SnackBar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = _buildContainer(
      document: _documentWith(<String>[
        'Estimada Ana, confirmamos el envío.',
        'Escríbenos a ana@example.com si hay dudas.',
      ]),
    );
    addTearDown(container.dispose);
    await _loadWorkbench(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Auto-mapear'));
    await tester.pumpAndSettle();

    final assignments = container.read(activeMappingProvider).state.assignments;
    expect(assignments, hasLength(2));
    expect(
      assignments.map((assignment) => assignment.fieldHeader),
      containsAll(<String>['nombre', 'correo']),
    );
    expect(
      find.text('2 campos auto-mapeados. Revisa y ajusta si es necesario.'),
      findsOneWidget,
    );
  });

  testWidgets('Auto-mapear avisa con la cuenta real antes de aplicar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 12 coincidencias de "Ana" superan el umbral de 10; el correo, con una
    // sola, no debe aparecer en el aviso.
    final container = _buildContainer(
      document: _documentWith(<String>[
        List<String>.filled(12, 'Ana').join(' y '),
        'Escríbenos a ana@example.com si hay dudas.',
      ]),
    );
    addTearDown(container.dispose);
    await _loadWorkbench(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Auto-mapear'));
    await tester.pumpAndSettle();

    expect(find.text('Coincidencias repetidas'), findsOneWidget);
    expect(find.text('"nombre"'), findsOneWidget);
    expect(find.text('12 coincidencias'), findsOneWidget);
    expect(find.text('"correo"'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(container.read(activeMappingProvider).state.assignments, isEmpty);
    expect(find.textContaining('auto-mapeados'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Auto-mapear'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    expect(
      container.read(activeMappingProvider).state.assignments,
      hasLength(13),
    );
    expect(
      find.text('13 campos auto-mapeados. Revisa y ajusta si es necesario.'),
      findsOneWidget,
    );
  });
}

Future<void> _loadWorkbench(ProviderContainer container) async {
  await container
      .read(activeProjectProvider.notifier)
      .createProject(name: 'Proyecto Auto-mapeo');
  await container
      .read(activeTemplateProvider.notifier)
      .importTemplate(filePath: '/tmp/plantilla.docx');
  await container
      .read(activeDatasourceProvider.notifier)
      .importDatasource(filePath: '/tmp/clientes.csv');
  container.read(workbenchEnteredProvider.notifier).enterWorkbench();
}

ProviderContainer _buildContainer({Document? document}) {
  return ProviderContainer(
    overrides: <Override>[
      loggingServiceProvider.overrideWithValue(FakeLoggingService()),
      projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
      datasourceRepositoryProvider.overrideWithValue(
        FakeDatasourceRepository(),
      ),
      templateRepositoryProvider.overrideWithValue(FakeTemplateRepository()),
      documentRepositoryProvider.overrideWithValue(
        FakeDocumentRepository(
          loadHandler: document == null ? null : (_) async => document,
        ),
      ),
      windowServiceProvider.overrideWithValue(FakeWindowService()),
    ],
  );
}

Document _documentWith(List<String> paragraphs) {
  return Document(
    pages: <DocumentPage>[
      DocumentPage(
        number: 1,
        widthPoints: 612,
        heightPoints: 792,
        margins: const DocumentMargins(
          topPoints: 72,
          rightPoints: 72,
          bottomPoints: 72,
          leftPoints: 72,
        ),
        blocks: <DocumentBlock>[
          for (final text in paragraphs)
            DocumentBlock.paragraph(
              DocumentParagraph(
                runs: <DocumentRun>[
                  DocumentRun(
                    text: text,
                    isBold: false,
                    isItalic: false,
                    isUnderlined: false,
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
    omissions: const <DocumentOmission>{},
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
