import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/workspace/workspace_paths.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/data/excel_file_watcher.dart';
import 'package:forkumentos/features/datasource/data/excel_opener.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/datasource/presentation/datasource_sync_controller.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

import '../../../../support/fakes.dart';

void main() {
  late Directory root;
  late WorkspacePaths paths;
  late int loads;
  late _RecordingOpener opener;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('forkumentos_sync_test_');
    paths = WorkspacePaths(root: root.path);
    loads = 0;
    opener = _RecordingOpener();
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  File write(String path, String content) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  /// Excel de ejemplo: una fila de encabezado y tantas filas como líneas.
  String csv(int rows) => 'nombre\n${List.filled(rows, 'x').join('\n')}\n';

  ProviderContainer containerFor(Project project) {
    final container = ProviderContainer(
      overrides: <Override>[
        loggingServiceProvider.overrideWithValue(FakeLoggingService()),
        workspacePathsProvider.overrideWithValue(paths),
        projectRepositoryProvider.overrideWithValue(
          _FakeProjectRepository(project),
        ),
        datasourceRepositoryProvider.overrideWithValue(
          FakeDatasourceRepository(
            loadHandler: (path) async {
              loads++;
              final file = File(path);
              final stat = file.statSync();
              final lines = file.readAsLinesSync();
              return Datasource(
                sourcePath: path,
                fileName: p.basename(path),
                fileSizeBytes: stat.size,
                fileModifiedAt: stat.modified,
                importedAt: DateTime.utc(2026),
                format: DatasourceFormat.csv,
                headers: const <String>['nombre'],
                previewRow: const <String?>[null],
                rowCount: lines.length - 1,
                emptyColumnIndexes: const <int>[],
              );
            },
          ),
        ),
        excelOpenerProvider.overrideWithValue(opener),
        excelFileWatcherFactoryProvider.overrideWithValue(
          (path) => ExcelFileWatcher(
            filePath: path,
            debounce: const Duration(milliseconds: 120),
            stabilityInterval: const Duration(milliseconds: 50),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Espera a que el Excel activo esté cargado y cumpla [matches]: cambiar la
  /// ruta embebida del proyecto recarga el Excel de forma asíncrona.
  Future<void> waitForRows(
    ProviderContainer container,
    bool Function(int rowCount) matches,
  ) async {
    for (var i = 0; i < 100; i++) {
      final rows = container
          .read(activeDatasourceProvider)
          .valueOrNull
          ?.rowCount;
      if (rows != null && matches(rows)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('El Excel activo no llegó al estado esperado.');
  }

  /// Abre el proyecto como lo haría el usuario: carga el .fork (su copia
  /// embebida pasa a ser el Excel activo) y espera a que se lea.
  Future<void> openProject(ProviderContainer container) async {
    await container
        .read(activeProjectProvider.notifier)
        .loadProject(filePath: 'proyecto.fork');
    await waitForRows(container, (_) => true);
  }

  String managedFolder(Project project) => paths.managedDatasourceFolder(
    projectName: project.name,
    projectId: project.id,
  );

  /// Proyecto guardado cuyo Excel gestionado ya existe y cuya huella
  /// [syncedStat] es la de ese archivo.
  ({Project project, File managed, File snapshot}) savedProject({
    bool synced = true,
  }) {
    var project = Project(
      id: 'abcdef0123456789',
      name: 'Contrato',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final managed = write(p.join(managedFolder(project), 'datos.csv'), csv(2));
    final snapshot = write(
      p.join(root.path, 'Cache', project.id, 'datasource', 'datos.csv'),
      csv(2),
    );
    final stat = managed.statSync();
    project = project.copyWith(
      embeddedDatasourcePath: snapshot.path,
      datasourceExternalPath: managed.path,
      datasourceSyncedMtimeMs: synced
          ? stat.modified.millisecondsSinceEpoch
          : null,
      datasourceSyncedSizeBytes: synced ? stat.size : null,
    );
    return (project: project, managed: managed, snapshot: snapshot);
  }

  test('refrescar con cambios apunta el proyecto al Excel gestionado y '
      'recuerda su huella', () async {
    final setup = savedProject();
    final container = containerFor(setup.project);
    await openProject(container);
    loads = 0;

    setup.managed.writeAsStringSync(csv(5));
    final result = await container
        .read(datasourceSyncControllerProvider)
        .refresh();

    expect(result.status, DatasourceRefreshStatus.updated);
    final project = container.read(activeProjectProvider).requireValue!;
    expect(project.embeddedDatasourcePath, setup.managed.path);
    final stat = setup.managed.statSync();
    expect(
      project.datasourceSyncedMtimeMs,
      stat.modified.millisecondsSinceEpoch,
    );
    expect(project.datasourceSyncedSizeBytes, stat.size);
  });

  test(
    'refrescar sin cambios recuerda la huella sin ensuciar el proyecto',
    () async {
      final setup = savedProject(synced: false);
      final container = containerFor(setup.project);
      await openProject(container);

      final result = await container
          .read(datasourceSyncControllerProvider)
          .refresh();

      expect(result.status, DatasourceRefreshStatus.unchanged);
      final project = container.read(activeProjectProvider).requireValue!;
      expect(project.datasourceSyncedMtimeMs, isNotNull);
      expect(project.isDirty, isFalse);
    },
  );

  test('al abrir, un Excel sin cambios desde la última huella no se vuelve '
      'a leer', () async {
    final setup = savedProject();
    final container = containerFor(setup.project);
    await openProject(container);
    loads = 0;

    await container.read(datasourceSyncControllerProvider).syncOnOpen();

    expect(loads, 0);
    expect(container.read(datasourceSyncMessageProvider), isNull);
  });

  test('al abrir, un Excel editado mientras la app estaba cerrada se vuelve '
      'a leer y se avisa', () async {
    final setup = savedProject();
    final container = containerFor(setup.project);
    await openProject(container);

    setup.managed.writeAsStringSync(csv(6));
    await container.read(datasourceSyncControllerProvider).syncOnOpen();
    await waitForRows(container, (rows) => rows == 6);

    expect(container.read(activeDatasourceProvider).valueOrNull?.rowCount, 6);
    expect(
      container.read(datasourceSyncMessageProvider),
      'Datos actualizados: +4 filas nuevas',
    );
    expect(
      container
          .read(activeProjectProvider)
          .requireValue!
          .embeddedDatasourcePath,
      setup.managed.path,
    );
  });

  test('al abrir un proyecto de una versión anterior migra el Excel original '
      'a la carpeta gestionada', () async {
    final original = write(
      p.join(root.path, 'Escritorio', 'clientes.csv'),
      csv(3),
    );
    var project = Project(
      id: 'abcdef0123456789',
      name: 'Contrato',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final snapshot = write(
      p.join(root.path, 'Cache', project.id, 'datasource', 'clientes.csv'),
      csv(3),
    );
    project = project.copyWith(
      embeddedDatasourcePath: snapshot.path,
      datasourceExternalPath: original.path,
    );
    final container = containerFor(project);
    await openProject(container);

    await container.read(datasourceSyncControllerProvider).syncOnOpen();

    final managedPath = p.join(managedFolder(project), 'clientes.csv');
    final opened = container.read(activeProjectProvider).requireValue!;
    expect(opened.datasourceExternalPath, managedPath);
    expect(File(managedPath).existsSync(), isTrue);
    expect(original.existsSync(), isTrue);
    expect(
      container.read(datasourceSyncMessageProvider),
      contains(managedPath),
    );
  });

  test(
    'si el Excel gestionado ya no existe, abrir no falla ni avisa',
    () async {
      final setup = savedProject();
      final container = containerFor(setup.project);
      await openProject(container);
      setup.managed.deleteSync();

      await container.read(datasourceSyncControllerProvider).syncOnOpen();

      expect(container.read(datasourceSyncMessageProvider), isNull);
      // El proyecto sigue con la copia embebida.
      expect(container.read(activeDatasourceProvider).valueOrNull, isNotNull);
    },
  );

  test(
    'abrir el Excel gestionado lo lanza con la aplicación predeterminada',
    () async {
      final setup = savedProject();
      final container = containerFor(setup.project);
      await openProject(container);

      final opened = await container
          .read(datasourceSyncControllerProvider)
          .openManagedExcel();

      expect(opened, isTrue);
      expect(opener.opened, <String>[setup.managed.path]);
    },
  );

  test('abrir el Excel sin archivo devuelve false', () async {
    final setup = savedProject();
    final container = containerFor(setup.project);
    await openProject(container);
    setup.managed.deleteSync();

    expect(
      await container.read(datasourceSyncControllerProvider).openManagedExcel(),
      isFalse,
    );
    expect(opener.opened, isEmpty);
  });

  test(
    'guardar el Excel mientras el proyecto está abierto actualiza solo',
    () async {
      final setup = savedProject();
      // El listener lo mantiene vivo la app; aquí se mantiene con listen.
      final container = containerFor(setup.project)
        ..listen(datasourceSyncListenerProvider, (_, __) {});
      await openProject(container);
      // Deja pasar la comprobación al abrir (no hay cambios) y arrancar el
      // observer.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      setup.managed.writeAsStringSync(csv(7));

      await waitForRows(container, (rows) => rows == 7);
      expect(container.read(activeDatasourceProvider).valueOrNull?.rowCount, 7);
      expect(
        container.read(datasourceSyncMessageProvider),
        'Datos actualizados: +5 filas nuevas',
      );
    },
  );
}

final class _RecordingOpener extends ExcelOpener {
  final List<String> opened = <String>[];

  @override
  Future<bool> open(String path) async {
    opened.add(path);
    return true;
  }
}

final class _FakeProjectRepository implements ProjectRepository {
  _FakeProjectRepository(this._project);

  final Project _project;

  @override
  Future<Project> load(
    String filePath, {
    required String cacheDirectory,
  }) async => _project.copyWith(filePath: filePath, isDirty: false);

  @override
  Future<Project> save({
    required Project project,
    required String filePath,
    String? templateSourcePath,
    String? datasourceSourcePath,
    String? cacheDirectory,
  }) async => project.copyWith(filePath: filePath);
}
