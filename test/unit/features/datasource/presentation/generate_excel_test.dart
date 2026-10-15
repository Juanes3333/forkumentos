import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/workspace/workspace_paths.dart';
import 'package:forkumentos/features/datasource/data/xlsx_datasource_repository.dart';
import 'package:forkumentos/features/datasource/data/xlsx_workbook_writer.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/datasource/presentation/datasource_sync_controller.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

import '../../../../support/fakes.dart';

void main() {
  late Directory root;
  late ProviderContainer container;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('forkumentos_generate_test_');
    container = ProviderContainer(
      overrides: <Override>[
        loggingServiceProvider.overrideWithValue(FakeLoggingService()),
        workspacePathsProvider.overrideWithValue(
          WorkspacePaths(root: root.path),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await root.delete(recursive: true);
  });

  test(
    'el libro nuevo tiene los encabezados en orden y ninguna fila',
    () async {
      final bytes = const XlsxWorkbookWriter().create(<String>[
        'nombre',
        'cédula',
        'correo',
      ]);
      final file = File(p.join(root.path, 'nuevo.xlsx'))
        ..writeAsBytesSync(bytes);

      final datasource = await const XlsxDatasourceRepository().load(file.path);

      expect(datasource.headers, <String>['nombre', 'cédula', 'correo']);
      expect(datasource.rowCount, 0);
    },
  );

  test('generar el Excel crea el archivo gestionado, lo vuelve la fuente de '
      'datos y vacía los campos borrador', () async {
    container.read(activeDatasourceProvider);
    final project = container.read(activeProjectProvider.notifier);
    await project.createProject(name: 'Solo Word');
    project
      ..insertDraftField('nombre', 0)
      ..insertDraftField('cédula', 1);
    final id = container.read(activeProjectProvider).requireValue!.id;

    final outcome = await container
        .read(datasourceSyncControllerProvider)
        .generateExcel();

    final folder = WorkspacePaths(
      root: root.path,
    ).managedDatasourceFolder(projectName: 'Solo Word', projectId: id);
    expect(outcome.error, isNull);
    expect(outcome.path, p.join(folder, 'Solo Word.xlsx'));
    expect(File(outcome.path!).existsSync(), isTrue);

    final current = container.read(activeProjectProvider).requireValue!;
    expect(current.draftFields, isEmpty);
    expect(current.datasourceExternalPath, outcome.path);
    expect(current.embeddedDatasourcePath, outcome.path);
    expect(current.datasourceSyncedMtimeMs, isNotNull);

    // El Excel activo se lee del archivo generado, con los mismos campos.
    for (var i = 0; i < 100; i++) {
      final datasource = container.read(activeDatasourceProvider).valueOrNull;
      if (datasource != null && !datasource.fileName.startsWith('Campos')) {
        expect(datasource.headers, <String>['nombre', 'cédula']);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('El Excel generado no llegó a cargarse como fuente activa.');
  });

  test('sin campos no genera nada y explica por qué', () async {
    final project = container.read(activeProjectProvider.notifier);
    await project.createProject(name: 'Solo Word');

    final outcome = await container
        .read(datasourceSyncControllerProvider)
        .generateExcel();

    expect(outcome.path, isNull);
    expect(outcome.error, contains('Crea al menos un campo'));
  });
}
