import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/datasource/presentation/datasource_management_screen.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../../../support/fakes.dart';

void main() {
  testWidgets('estado vacío muestra botón de importar datos', (
    WidgetTester tester,
  ) async {
    final fakeDatasourceRepository = FakeDatasourceRepository();
    final container = _buildContainer(fakeDatasourceRepository);
    addTearDown(container.dispose);
    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DatasourceManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Importar datos'), findsOneWidget);
    expect(find.text('Fuente de datos'), findsOneWidget);
  });

  testWidgets('después de importar muestra detalles, headers y preview', (
    WidgetTester tester,
  ) async {
    final fakeDatasourceRepository = FakeDatasourceRepository(
      loadHandler: (String filePath) async {
        return Datasource(
          sourcePath: filePath,
          fileName: 'clientes.xlsx',
          fileSizeBytes: 4096,
          importedAt: DateTime.utc(2026, 7, 9, 20, 15),
          format: DatasourceFormat.xlsx,
          headers: const <String>['nombre', 'correo', 'telefono'],
          previewRow: const <String?>['Ana', 'ana@example.com', null],
          rowCount: 12,
          emptyColumnIndexes: const <int>[2],
        );
      },
    );
    final container = _buildContainer(fakeDatasourceRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/clientes.xlsx');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DatasourceManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fuente de datos activa'), findsOneWidget);
    expect(find.text('clientes.xlsx'), findsOneWidget);
    expect(find.text('XLSX'), findsOneWidget);
    expect(find.text('12'), findsAtLeastNWidgets(1));
    expect(find.text('nombre'), findsAtLeastNWidgets(1));
    expect(find.text('correo'), findsAtLeastNWidgets(1));
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(
      find.text(
        'Esta vista previa representa solo el primer registro. '
        'Todas las filas se usarán durante la exportación.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('telefono'), findsAtLeastNWidgets(1));
    expect(find.text('Reemplazar datos'), findsOneWidget);
    expect(find.text('Quitar datos'), findsOneWidget);
  });

  testWidgets('reemplazar datos refleja la nueva fuente importada', (
    WidgetTester tester,
  ) async {
    final fakeDatasourceRepository = FakeDatasourceRepository(
      loadHandler: (String filePath) async {
        if (filePath.endsWith('a.csv')) {
          return _buildDatasource(fileName: 'a.csv', rowCount: 2);
        }
        return _buildDatasource(
          fileName: 'b.xlsx',
          format: DatasourceFormat.xlsx,
          rowCount: 5,
        );
      },
    );
    final container = _buildContainer(fakeDatasourceRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/a.csv');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/b.xlsx');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DatasourceManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('b.xlsx'), findsOneWidget);
    expect(find.text('a.csv'), findsNothing);
  });

  testWidgets('quitar datos vuelve al estado vacío', (
    WidgetTester tester,
  ) async {
    final fakeDatasourceRepository = FakeDatasourceRepository(
      loadHandler: (String filePath) async =>
          _buildDatasource(fileName: 'clientes.csv'),
    );
    final container = _buildContainer(fakeDatasourceRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/clientes.csv');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DatasourceManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Quitar datos'));
    await tester.tap(find.text('Quitar datos'));
    await tester.pumpAndSettle();

    expect(find.text('clientes.csv'), findsNothing);
    expect(find.text('Importar datos'), findsOneWidget);
  });

  testWidgets('estado de error se muestra y puede cerrarse', (
    WidgetTester tester,
  ) async {
    final fakeDatasourceRepository = FakeDatasourceRepository(
      loadHandler: (_) async => throw const FormatException('Fuente inválida'),
    );
    final container = _buildContainer(fakeDatasourceRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/invalida.csv');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DatasourceManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fuente inválida'), findsOneWidget);

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Fuente inválida'), findsNothing);
    expect(find.text('Importar datos'), findsOneWidget);
  });
}

ProviderContainer _buildContainer(
  FakeDatasourceRepository datasourceRepository,
) {
  return ProviderContainer(
    overrides: <Override>[
      loggingServiceProvider.overrideWithValue(FakeLoggingService()),
      projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
      datasourceRepositoryProvider.overrideWithValue(datasourceRepository),
    ],
  );
}

Datasource _buildDatasource({
  required String fileName,
  DatasourceFormat format = DatasourceFormat.csv,
  int rowCount = 1,
}) {
  return Datasource(
    sourcePath: '/tmp/$fileName',
    fileName: fileName,
    fileSizeBytes: 2048,
    importedAt: DateTime.utc(2026, 7, 9, 20, 15),
    format: format,
    headers: const <String>['nombre', 'correo'],
    previewRow: const <String?>['Ana', 'ana@example.com'],
    rowCount: rowCount,
    emptyColumnIndexes: const <int>[],
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
