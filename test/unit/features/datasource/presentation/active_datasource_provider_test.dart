import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/workspace/workspace_paths.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/data/managed_datasource_store.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/domain/draft_datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';
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

  test('whenIdle espera a la importación en vuelo, incluso si falla', () async {
    final pendingLoad = Completer<Datasource>();
    final container = _createContainer(
      FakeDatasourceRepository(loadHandler: (_) => pendingLoad.future),
    );
    addTearDown(container.dispose);
    final notifier = container.read(activeDatasourceProvider.notifier);

    await notifier.whenIdle();
    unawaited(notifier.importDatasource(filePath: '/tmp/lento.csv'));
    var idle = false;
    final waiting = notifier.whenIdle().then((_) => idle = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(idle, isFalse);

    pendingLoad.completeError(StateError('archivo roto'));
    await waiting;

    expect(idle, isTrue);
  });

  group('fuente borrador (proyecto solo con Word)', () {
    test('los campos creados sobre el documento se exponen como encabezados '
        'de una fuente sin archivo, en orden', () async {
      final container = _createContainer(FakeDatasourceRepository());
      addTearDown(container.dispose);
      container.read(activeDatasourceProvider);
      final project = container.read(activeProjectProvider.notifier);
      await project.createProject(name: 'Solo Word');

      project
        ..insertDraftField('nombre', 0)
        ..insertDraftField('cédula', 1)
        ..insertDraftField('apellido', 1);

      final datasource = container.read(activeDatasourceProvider).valueOrNull;
      expect(datasource, isNotNull);
      expect(datasource!.isDraft, isTrue);
      expect(datasource.headers, <String>['nombre', 'apellido', 'cédula']);
      expect(datasource.rowCount, 0);
    });

    test('un campo repetido no se inserta dos veces', () async {
      final container = _createContainer(FakeDatasourceRepository());
      addTearDown(container.dispose);
      container.read(activeDatasourceProvider);
      final project = container.read(activeProjectProvider.notifier);
      await project.createProject(name: 'Solo Word');

      project
        ..insertDraftField('nombre', 0)
        ..insertDraftField('nombre', 0);

      expect(
        container.read(activeProjectProvider).requireValue!.draftFields,
        <String>['nombre'],
      );
    });

    test('al asignar un Excel real se vacían los campos borrador', () async {
      final container = _createContainer(
        FakeDatasourceRepository(
          loadHandler: (path) async => _buildDatasource(path),
        ),
      );
      addTearDown(container.dispose);
      container.read(activeDatasourceProvider);
      final project = container.read(activeProjectProvider.notifier);
      await project.createProject(name: 'Solo Word');
      project
        ..insertDraftField('nombre', 0)
        ..setEmbeddedArtifactPaths(datasourcePath: '/tmp/datos.csv');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        container.read(activeProjectProvider).requireValue!.draftFields,
        isEmpty,
      );
      final datasource = container.read(activeDatasourceProvider).valueOrNull;
      expect(datasource?.isDraft, isFalse);
    });
  });

  group('Excel gestionado por la app', () {
    late Directory workspaceRoot;

    setUp(() async {
      workspaceRoot = await Directory.systemTemp.createTemp(
        'forkumentos_managed_import_test_',
      );
      addTearDown(() => workspaceRoot.delete(recursive: true));
    });

    ProviderContainer containerWithWorkspace(
      FakeDatasourceRepository repository,
    ) {
      final container = ProviderContainer(
        overrides: <Override>[
          loggingServiceProvider.overrideWithValue(FakeLoggingService()),
          projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
          datasourceRepositoryProvider.overrideWithValue(repository),
          workspacePathsProvider.overrideWithValue(
            WorkspacePaths(root: workspaceRoot.path),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('importar copia el archivo a la carpeta del proyecto y trabaja sobre '
        'esa copia', () async {
      final original = File(p.join(workspaceRoot.path, 'Escritorio', 'a.csv'))
        ..createSync(recursive: true)
        ..writeAsStringSync('nombre\nAna\n');
      final loaded = <String>[];
      final container = containerWithWorkspace(
        FakeDatasourceRepository(
          loadHandler: (path) async {
            loaded.add(path);
            return _buildDatasource(path);
          },
        ),
      );
      await container
          .read(activeProjectProvider.notifier)
          .createProject(name: 'Contrato');
      final project = container.read(activeProjectProvider).requireValue!;

      await container
          .read(activeDatasourceProvider.notifier)
          .importDatasource(filePath: original.path);

      final managedFolder = WorkspacePaths(root: workspaceRoot.path)
          .managedDatasourceFolder(
            projectName: project.name,
            projectId: project.id,
          );
      final managedPath = p.join(managedFolder, 'a.csv');
      expect(loaded, <String>[managedPath]);
      expect(File(managedPath).readAsStringSync(), 'nombre\nAna\n');
      expect(original.existsSync(), isTrue);
      expect(
        container.read(activeDatasourceProvider).valueOrNull?.sourcePath,
        managedPath,
      );
    });

    test('sin proyecto activo se importa el archivo tal cual', () async {
      final original = File(p.join(workspaceRoot.path, 'a.csv'))
        ..writeAsStringSync('nombre\nAna\n');
      final loaded = <String>[];
      final container = containerWithWorkspace(
        FakeDatasourceRepository(
          loadHandler: (path) async {
            loaded.add(path);
            return _buildDatasource(path);
          },
        ),
      );

      await container
          .read(activeDatasourceProvider.notifier)
          .importDatasource(filePath: original.path);

      expect(loaded, <String>[original.path]);
    });

    test('si el destino está bloqueado muestra un error claro y conserva la '
        'fuente previa', () async {
      final folderless = _LockedStore();
      final original = File(p.join(workspaceRoot.path, 'a.csv'))
        ..writeAsStringSync('nombre\nAna\n');
      final container = ProviderContainer(
        overrides: <Override>[
          loggingServiceProvider.overrideWithValue(FakeLoggingService()),
          projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
          datasourceRepositoryProvider.overrideWithValue(
            FakeDatasourceRepository(
              loadHandler: (path) async => _buildDatasource(path),
            ),
          ),
          workspacePathsProvider.overrideWithValue(
            WorkspacePaths(root: workspaceRoot.path),
          ),
          managedDatasourceStoreProvider.overrideWithValue(folderless),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(activeProjectProvider.notifier)
          .createProject(name: 'Contrato');

      await container
          .read(activeDatasourceProvider.notifier)
          .importDatasource(filePath: original.path);

      final state = container.read(activeDatasourceProvider);
      expect(state.hasError, isTrue);
      expect(
        (state.error! as DatasourceLifecycleException).message,
        contains('abierto en Excel'),
      );
    });
  });

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

    test(
      'valores editados con mismo tamaño y forma devuelven updated',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'forkumentos_refresh_test_',
        );
        addTearDown(() => tempDirectory.delete(recursive: true));
        final path = p.join(tempDirectory.path, 'clientes.csv');
        File(path).writeAsStringSync('nombre,correo\nAna,ana@example.com\n');

        // Misma forma, tamaño y primera fila; solo cambia la fecha de edición.
        var loadCount = 0;
        final fakeDatasourceRepository = FakeDatasourceRepository(
          loadHandler: (filePath) async {
            loadCount++;
            return _buildDatasource(filePath).copyWith(
              fileModifiedAt: DateTime.utc(2026, 1, 1, 0, 0, loadCount),
            );
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
      },
    );

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

/// Almacén cuyo destino siempre está bloqueado (Excel tiene el archivo
/// abierto).
class _LockedStore extends ManagedDatasourceStore {
  @override
  Future<String> adopt({
    required String sourcePath,
    required String folder,
  }) async {
    throw FileSystemException('Archivo en uso', folder);
  }
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
