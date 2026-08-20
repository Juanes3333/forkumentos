import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/datasource/presentation/datasource_resource_card.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../../../support/fakes.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('datasource_card_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('botón refrescar está deshabilitado sin ruta externa existente', (
    WidgetTester tester,
  ) async {
    final container = _buildContainer(FakeDatasourceRepository());
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/ruta/inexistente/clientes.csv');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: DatasourceResourceCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Refrescar datos'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('refrescar sin cambios muestra snackbar informativo', (
    WidgetTester tester,
  ) async {
    final file = File('${tempDir.path}/clientes.csv')..writeAsStringSync('');
    final fakeRepository = FakeDatasourceRepository(
      loadHandler: (String filePath) async => Datasource(
        sourcePath: filePath,
        fileName: 'clientes.csv',
        fileSizeBytes: 100,
        importedAt: DateTime.utc(2026),
        format: DatasourceFormat.csv,
        headers: const <String>['nombre'],
        previewRow: const <String?>['Ana'],
        rowCount: 3,
        emptyColumnIndexes: const <int>[],
      ),
    );
    final container = _buildContainer(fakeRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');
    // Set both paths BEFORE activeDatasourceProvider is ever read: its
    // build() auto-loads from embeddedDatasourcePath, so the datasource
    // comes up already in sync with datasourceExternalPath — exactly the
    // steady state a real project reaches after import. (Setting these
    // paths *after* the provider is already built and loaded would change
    // embeddedDatasourcePath out from under a live AsyncNotifier that both
    // watches and listens to it, which trips a pre-existing Riverpod
    // reentrancy assertion in ActiveDatasourceNotifier — unrelated to this
    // feature, out of DesktopUIAgent's scope.)
    container
        .read(activeProjectProvider.notifier)
        .setEmbeddedArtifactPaths(datasourcePath: file.path);
    container
        .read(activeProjectProvider.notifier)
        .setDatasourceExternalPath(file.path);
    await container.read(activeDatasourceProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: DatasourceResourceCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Refrescar datos'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Refrescar datos'));
    await tester.pumpAndSettle();

    expect(find.text('El archivo no tiene cambios.'), findsOneWidget);
  });

  testWidgets('refrescar con nuevas filas muestra el delta', (
    WidgetTester tester,
  ) async {
    final file = File('${tempDir.path}/clientes.csv')..writeAsStringSync('');
    var callCount = 0;
    final fakeRepository = FakeDatasourceRepository(
      loadHandler: (String filePath) async {
        callCount++;
        return Datasource(
          sourcePath: filePath,
          fileName: 'clientes.csv',
          fileSizeBytes: 100,
          importedAt: DateTime.utc(2026),
          format: DatasourceFormat.csv,
          headers: const <String>['nombre'],
          previewRow: const <String?>['Ana'],
          rowCount: callCount == 1 ? 3 : 6,
          emptyColumnIndexes: const <int>[],
        );
      },
    );
    final container = _buildContainer(fakeRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto UI');
    // See the comment in the "sin cambios" test above: paths must be set
    // before activeDatasourceProvider is first read.
    container
        .read(activeProjectProvider.notifier)
        .setEmbeddedArtifactPaths(datasourcePath: file.path);
    container
        .read(activeProjectProvider.notifier)
        .setDatasourceExternalPath(file.path);
    await container.read(activeDatasourceProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: DatasourceResourceCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Refrescar datos'));
    await tester.pumpAndSettle();

    expect(find.text('Datos actualizados: +3 filas nuevas'), findsOneWidget);
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
