import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/template/data/template_repository_provider.dart';
import 'package:forkumentos/features/template/domain/template.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/features/template/presentation/template_management_screen.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../../../support/fakes.dart';

void main() {
  testWidgets('estado vacío muestra botón de importar plantilla', (
    WidgetTester tester,
  ) async {
    final fakeTemplateRepository = FakeTemplateRepository();
    final container = _buildContainer(fakeTemplateRepository);
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TemplateManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Importar plantilla'), findsOneWidget);
    expect(find.text('Plantilla'), findsOneWidget);
  });

  testWidgets('después de importar muestra metadatos de plantilla', (
    WidgetTester tester,
  ) async {
    final fakeTemplateRepository = FakeTemplateRepository(
      loadHandler: (String filePath) async {
        return Template(
          sourcePath: filePath,
          fileName: 'contrato.docx',
          fileSizeBytes: 2048,
          importedAt: DateTime.utc(2026, 7, 9, 20, 15),
          title: 'Contrato',
          author: 'María',
          pageCount: 3,
          wordCount: 450,
        );
      },
    );
    final container = _buildContainer(fakeTemplateRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');
    await container
        .read(activeTemplateProvider.notifier)
        .importTemplate(filePath: '/tmp/contrato.docx');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TemplateManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plantilla activa'), findsOneWidget);
    expect(find.text('contrato.docx'), findsOneWidget);
    expect(find.text('Contrato'), findsOneWidget);
    expect(find.text('María'), findsOneWidget);
    expect(find.text('Reemplazar plantilla'), findsOneWidget);
    expect(find.text('Quitar plantilla'), findsOneWidget);
  });

  testWidgets('quitar plantilla vuelve al estado vacío', (
    WidgetTester tester,
  ) async {
    final fakeTemplateRepository = FakeTemplateRepository(
      loadHandler: (String filePath) async {
        return Template(
          sourcePath: filePath,
          fileName: 'contrato.docx',
          fileSizeBytes: 2048,
          importedAt: DateTime.utc(2026, 7, 9, 20, 15),
        );
      },
    );
    final container = _buildContainer(fakeTemplateRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');
    await container
        .read(activeTemplateProvider.notifier)
        .importTemplate(filePath: '/tmp/contrato.docx');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TemplateManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quitar plantilla'));
    await tester.pumpAndSettle();

    expect(find.text('contrato.docx'), findsNothing);
    expect(find.text('Importar plantilla'), findsOneWidget);
  });

  testWidgets('estado de error se muestra y puede cerrarse', (
    WidgetTester tester,
  ) async {
    final fakeTemplateRepository = FakeTemplateRepository(
      loadHandler: (_) async =>
          throw const FormatException('Plantilla inválida'),
    );
    final container = _buildContainer(fakeTemplateRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');
    await container
        .read(activeTemplateProvider.notifier)
        .importTemplate(filePath: '/tmp/invalida.docx');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TemplateManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plantilla inválida'), findsOneWidget);

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Plantilla inválida'), findsNothing);
    expect(find.text('Importar plantilla'), findsOneWidget);
  });
}

ProviderContainer _buildContainer(FakeTemplateRepository templateRepository) {
  return ProviderContainer(
    overrides: <Override>[
      loggingServiceProvider.overrideWithValue(FakeLoggingService()),
      projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
      templateRepositoryProvider.overrideWithValue(templateRepository),
    ],
  );
}

final class _FakeProjectRepository implements ProjectRepository {
  @override
  Future<Project> load(String filePath) async {
    return Project(
      id: 'project-ui',
      name: 'Proyecto UI',
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
