import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:path/path.dart' as p;

import '../../../../support/fakes.dart';

void main() {
  test('importDatasource carga y guarda la fuente de datos activa', () async {
    final fakeDatasourceRepository = FakeDatasourceRepository();
    final container = _createContainer(fakeDatasourceRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto con Datos');

    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/clientes.csv');

    final state = container.read(activeDatasourceProvider);
    expect(state.hasError, isFalse);
    expect(state.valueOrNull?.fileName, 'clientes.csv');
  });

  test('importDatasource reemplaza la fuente activa', () async {
    final fakeDatasourceRepository = FakeDatasourceRepository();
    final container = _createContainer(fakeDatasourceRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto con Datos');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/primero.csv');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/segundo.xlsx');

    expect(
      container.read(activeDatasourceProvider).valueOrNull?.fileName,
      'segundo.xlsx',
    );
  });

  test(
    'importDatasource clasifica errores con DatasourceLifecycleException',
    () async {
      final fakeDatasourceRepository = FakeDatasourceRepository(
        loadHandler: (_) async => throw const FormatException('CSV inválido'),
      );
      final container = _createContainer(fakeDatasourceRepository);
      addTearDown(container.dispose);

      await container
          .read(activeProjectProvider.notifier)
          .createProject(name: 'Proyecto con Error');

      await container
          .read(activeDatasourceProvider.notifier)
          .importDatasource(filePath: '/tmp/invalido.csv');

      final state = container.read(activeDatasourceProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<DatasourceLifecycleException>());
      expect(
        (state.error! as DatasourceLifecycleException).message,
        'CSV inválido',
      );
    },
  );

  test('removeDatasource limpia la fuente de datos activa', () async {
    final fakeDatasourceRepository = FakeDatasourceRepository();
    final container = _createContainer(fakeDatasourceRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/clientes.csv');

    await container.read(activeDatasourceProvider.notifier).removeDatasource();

    final state = container.read(activeDatasourceProvider);
    expect(state.hasError, isFalse);
    expect(state.valueOrNull, isNull);
  });

  test('dismissError restaura la fuente previa', () async {
    final fakeDatasourceRepository = FakeDatasourceRepository();
    final container = _createContainer(fakeDatasourceRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/ok.csv');

    fakeDatasourceRepository.loadHandler = (_) async =>
        throw const FormatException('No válido');
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/fail.csv');

    final failedState = container.read(activeDatasourceProvider);
    expect(failedState.hasError, isTrue);

    container.read(activeDatasourceProvider.notifier).dismissError();

    final restoredState = container.read(activeDatasourceProvider);
    expect(restoredState.hasError, isFalse);
    expect(restoredState.valueOrNull?.fileName, 'ok.csv');
  });

  test('cambiar o limpiar proyecto activo limpia la fuente de datos', () async {
    final fakeDatasourceRepository = FakeDatasourceRepository();
    final container = _createContainer(fakeDatasourceRepository);
    addTearDown(container.dispose);

    final projectNotifier = container.read(activeProjectProvider.notifier);
    final datasourceNotifier = container.read(
      activeDatasourceProvider.notifier,
    );

    await projectNotifier.createProject(name: 'Proyecto A');
    await datasourceNotifier.importDatasource(filePath: '/tmp/a.csv');
    expect(container.read(activeDatasourceProvider).valueOrNull, isNotNull);

    await projectNotifier.createProject(name: 'Proyecto B');
    expect(container.read(activeDatasourceProvider).valueOrNull, isNull);

    await datasourceNotifier.importDatasource(filePath: '/tmp/b.csv');
    expect(container.read(activeDatasourceProvider).valueOrNull, isNotNull);

    await projectNotifier.closeProject();
    expect(container.read(activeDatasourceProvider).valueOrNull, isNull);
  });

  test(
    'regresión: setEmbeddedArtifactPaths con el proyecto ya cargado no '
    'produce reentrancia de Riverpod (watch+listen sobre el mismo selector)',
    () async {
      // Reproduces the crash the desktop-ui-specialist agent found: with the
      // datasource already loaded (not during the provider's first build),
      // pointing embeddedDatasourcePath at a *different* path synchronously
      // fires ActiveDatasourceNotifier's own `ref.listen` callback, which
      // calls importDatasource -> ref.read(...). Before the fix (build()
      // both `watch`ed and `listen`ed the same selector), that `ref.read`
      // hit Riverpod's `_assertNotOutdated` and threw. This exercises the
      // exact same existing APIs (importDatasource + setEmbeddedArtifactPaths)
      // the UI agent used to reproduce it, with the project already loaded
      // before either call — the normal "Reemplazar"/"Refrescar" case.
      final fakeDatasourceRepository = FakeDatasourceRepository();
      final container = _createContainer(fakeDatasourceRepository);
      addTearDown(container.dispose);

      final projectNotifier = container.read(activeProjectProvider.notifier);
      final datasourceNotifier = container.read(
        activeDatasourceProvider.notifier,
      );

      await projectNotifier.createProject(name: 'Proyecto');
      await datasourceNotifier.importDatasource(filePath: '/tmp/primero.csv');
      // Force the provider to have already completed its initial build
      // (reading state) before the reactive mutation below, matching how a
      // real app has the datasource card already rendered.
      expect(
        container.read(activeDatasourceProvider).valueOrNull?.fileName,
        'primero.csv',
      );

      expect(
        () => projectNotifier.setEmbeddedArtifactPaths(
          datasourcePath: '/tmp/segundo.csv',
        ),
        returnsNormally,
      );

      // The listen callback's unawaited importDatasource needs a beat to
      // resolve.
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(activeDatasourceProvider).valueOrNull?.fileName,
        'segundo.csv',
      );
    },
  );

  test(
    'una importación que resuelve tras cambiar de proyecto no se aplica',
    () async {
      final pendingLoad = Completer<Datasource>();
      final fakeDatasourceRepository = FakeDatasourceRepository(
        loadHandler: (_) => pendingLoad.future,
      );
      final container = _createContainer(fakeDatasourceRepository);
      addTearDown(container.dispose);

      final projectNotifier = container.read(activeProjectProvider.notifier);
      final datasourceNotifier = container.read(
        activeDatasourceProvider.notifier,
      );

      await projectNotifier.createProject(name: 'Proyecto A');
      final importFuture = datasourceNotifier.importDatasource(
        filePath: '/tmp/lento.csv',
      );

      await projectNotifier.createProject(name: 'Proyecto B');
      pendingLoad.complete(_buildDatasource('/tmp/lento.csv'));
      await importFuture;

      expect(container.read(activeDatasourceProvider).valueOrNull, isNull);
    },
  );

  group('refreshDatasource', () {
    test(
      'sin datasourceExternalPath devuelve notFound sin tocar el estado',
      () async {
        final fakeDatasourceRepository = FakeDatasourceRepository();
        final container = _createContainer(fakeDatasourceRepository);
        addTearDown(container.dispose);

        await container
            .read(activeProjectProvider.notifier)
            .createProject(name: 'Proyecto');
        await container
            .read(activeDatasourceProvider.notifier)
            .importDatasource(filePath: '/tmp/original.csv');

        final result = await container
            .read(activeDatasourceProvider.notifier)
            .refreshDatasource();

        expect(result.status, DatasourceRefreshStatus.notFound);
        expect(
          container.read(activeDatasourceProvider).valueOrNull?.rowCount,
          1,
        );
        expect(container.read(datasourceRefreshAvailableProvider), isFalse);
      },
    );

    test('con ruta que no existe en disco devuelve notFound', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'forkumentos_refresh_test_',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final missingPath = p.join(tempDirectory.path, 'no_existe.csv');

      final fakeDatasourceRepository = FakeDatasourceRepository();
      final container = _createContainer(fakeDatasourceRepository);
      addTearDown(container.dispose);

      await container
          .read(activeProjectProvider.notifier)
          .createProject(name: 'Proyecto');
      await container
          .read(activeDatasourceProvider.notifier)
          .importDatasource(filePath: '/tmp/original.csv');
      container
          .read(activeProjectProvider.notifier)
          .setDatasourceExternalPath(missingPath);

      expect(container.read(datasourceRefreshAvailableProvider), isFalse);

      final result = await container
          .read(activeDatasourceProvider.notifier)
          .refreshDatasource();

      expect(result.status, DatasourceRefreshStatus.notFound);
      expect(container.read(activeDatasourceProvider).valueOrNull?.rowCount, 1);
    });

    test('archivo sin cambios devuelve unchanged', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'forkumentos_refresh_test_',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final path = p.join(tempDirectory.path, 'clientes.csv');
      File(path).writeAsStringSync('nombre,correo\nAna,ana@example.com\n');

      final fakeDatasourceRepository = FakeDatasourceRepository();
      final container = _createContainer(fakeDatasourceRepository);
      addTearDown(container.dispose);

      await container
          .read(activeProjectProvider.notifier)
          .createProject(name: 'Proyecto');
      await container
          .read(activeDatasourceProvider.notifier)
          .importDatasource(filePath: path);
      container
          .read(activeProjectProvider.notifier)
          .setDatasourceExternalPath(path);

      expect(container.read(datasourceRefreshAvailableProvider), isTrue);

      final result = await container
          .read(activeDatasourceProvider.notifier)
          .refreshDatasource();

      expect(result.status, DatasourceRefreshStatus.unchanged);
      expect(container.read(activeDatasourceProvider).valueOrNull?.rowCount, 1);
    });

    test('archivo con filas nuevas devuelve updated con rowDelta', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'forkumentos_refresh_test_',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final path = p.join(tempDirectory.path, 'clientes.csv');
      File(path).writeAsStringSync('nombre,correo\nAna,ana@example.com\n');

      var loadCount = 0;
      final fakeDatasourceRepository = FakeDatasourceRepository(
        loadHandler: (filePath) async {
          loadCount++;
          return _buildDatasource(filePath, rowCount: loadCount == 1 ? 1 : 3);
        },
      );
      final container = _createContainer(fakeDatasourceRepository);
      addTearDown(container.dispose);

      await container
          .read(activeProjectProvider.notifier)
          .createProject(name: 'Proyecto');
      await container
          .read(activeDatasourceProvider.notifier)
          .importDatasource(filePath: path);
      container
          .read(activeProjectProvider.notifier)
          .setDatasourceExternalPath(path);

      final result = await container
          .read(activeDatasourceProvider.notifier)
          .refreshDatasource();

      expect(result.status, DatasourceRefreshStatus.updated);
      expect(result.rowDelta, 2);
      expect(container.read(activeDatasourceProvider).valueOrNull?.rowCount, 3);
    });

    test(
      'un error al releer se clasifica y no queda como excepción cruda',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'forkumentos_refresh_test_',
        );
        addTearDown(() => tempDirectory.delete(recursive: true));
        final path = p.join(tempDirectory.path, 'clientes.csv');
        File(path).writeAsStringSync('nombre,correo\nAna,ana@example.com\n');

        var loadCount = 0;
        final fakeDatasourceRepository = FakeDatasourceRepository(
          loadHandler: (filePath) async {
            loadCount++;
            if (loadCount == 1) {
              return _buildDatasource(filePath);
            }
            throw const FormatException('CSV corrupto');
          },
        );
        final container = _createContainer(fakeDatasourceRepository);
        addTearDown(container.dispose);

        await container
            .read(activeProjectProvider.notifier)
            .createProject(name: 'Proyecto');
        await container
            .read(activeDatasourceProvider.notifier)
            .importDatasource(filePath: path);
        container
            .read(activeProjectProvider.notifier)
            .setDatasourceExternalPath(path);

        final result = await container
            .read(activeDatasourceProvider.notifier)
            .refreshDatasource();

        expect(result.status, DatasourceRefreshStatus.error);
        expect(result.message, 'CSV corrupto');
      },
    );
  });

  test('solo la importación más reciente se aplica cuando resuelven fuera de '
      'orden', () async {
    final firstLoad = Completer<Datasource>();
    final secondLoad = Completer<Datasource>();
    var callCount = 0;
    final fakeDatasourceRepository = FakeDatasourceRepository(
      loadHandler: (_) {
        callCount++;
        return callCount == 1 ? firstLoad.future : secondLoad.future;
      },
    );
    final container = _createContainer(fakeDatasourceRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto');
    final datasourceNotifier = container.read(
      activeDatasourceProvider.notifier,
    );

    final firstImport = datasourceNotifier.importDatasource(
      filePath: '/tmp/primera.csv',
    );
    final secondImport = datasourceNotifier.importDatasource(
      filePath: '/tmp/segunda.csv',
    );

    secondLoad.complete(_buildDatasource('/tmp/segunda.csv'));
    await secondImport;
    firstLoad.complete(_buildDatasource('/tmp/primera.csv'));
    await firstImport;

    expect(
      container.read(activeDatasourceProvider).valueOrNull?.fileName,
      'segunda.csv',
    );
  });
}

ProviderContainer _createContainer(
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

Datasource _buildDatasource(String path, {int rowCount = 1}) {
  final fileName = path.split(RegExp(r'[\\/]')).last;
  return Datasource(
    sourcePath: path,
    fileName: fileName,
    fileSizeBytes: 10 + rowCount,
    importedAt: DateTime.utc(2026),
    format: path.toLowerCase().endsWith('.xlsx')
        ? DatasourceFormat.xlsx
        : DatasourceFormat.csv,
    headers: const <String>['nombre', 'correo'],
    previewRow: const <String?>['Ana', 'ana@example.com'],
    rowCount: rowCount,
    emptyColumnIndexes: const <int>[],
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
