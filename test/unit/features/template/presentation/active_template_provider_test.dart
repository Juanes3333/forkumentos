import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/template/data/template_repository_provider.dart';
import 'package:forkumentos/features/template/domain/template.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../../../support/fakes.dart';

void main() {
  test('importTemplate carga y guarda la plantilla activa', () async {
    final fakeTemplateRepository = FakeTemplateRepository();
    final container = _createContainer(fakeTemplateRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto con Plantilla');

    await container
        .read(activeTemplateProvider.notifier)
        .importTemplate(filePath: '/tmp/plantilla_base.docx');

    final state = container.read(activeTemplateProvider);
    expect(state.hasError, isFalse);
    expect(state.valueOrNull?.fileName, 'plantilla_base.docx');
  });

  test(
    'importTemplate clasifica errores con TemplateLifecycleException',
    () async {
      final fakeTemplateRepository = FakeTemplateRepository(
        loadHandler: (_) async => throw const FormatException('DOCX inválido'),
      );
      final container = _createContainer(fakeTemplateRepository);
      addTearDown(container.dispose);

      await container
          .read(activeProjectProvider.notifier)
          .createProject(name: 'Proyecto con Error');

      await container
          .read(activeTemplateProvider.notifier)
          .importTemplate(filePath: '/tmp/invalida.docx');

      final state = container.read(activeTemplateProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<TemplateLifecycleException>());
      expect(
        (state.error! as TemplateLifecycleException).message,
        'DOCX inválido',
      );
    },
  );

  test('removeTemplate limpia la plantilla activa', () async {
    final fakeTemplateRepository = FakeTemplateRepository();
    final container = _createContainer(fakeTemplateRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto');
    await container
        .read(activeTemplateProvider.notifier)
        .importTemplate(filePath: '/tmp/plantilla.docx');

    await container.read(activeTemplateProvider.notifier).removeTemplate();

    final state = container.read(activeTemplateProvider);
    expect(state.hasError, isFalse);
    expect(state.valueOrNull, isNull);
  });

  test('dismissError restaura la plantilla previa', () async {
    final fakeTemplateRepository = FakeTemplateRepository();
    final container = _createContainer(fakeTemplateRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto');
    await container
        .read(activeTemplateProvider.notifier)
        .importTemplate(filePath: '/tmp/ok.docx');

    fakeTemplateRepository.loadHandler = (_) async =>
        throw const FormatException('No válido');
    await container
        .read(activeTemplateProvider.notifier)
        .importTemplate(filePath: '/tmp/fail.docx');

    final failedState = container.read(activeTemplateProvider);
    expect(failedState.hasError, isTrue);

    container.read(activeTemplateProvider.notifier).dismissError();

    final restoredState = container.read(activeTemplateProvider);
    expect(restoredState.hasError, isFalse);
    expect(restoredState.valueOrNull?.fileName, 'ok.docx');
  });

  test('cambiar o limpiar proyecto activo limpia la plantilla', () async {
    final fakeTemplateRepository = FakeTemplateRepository();
    final container = _createContainer(fakeTemplateRepository);
    addTearDown(container.dispose);

    final projectNotifier = container.read(activeProjectProvider.notifier);
    final templateNotifier = container.read(activeTemplateProvider.notifier);

    await projectNotifier.createProject(name: 'Proyecto A');
    await templateNotifier.importTemplate(filePath: '/tmp/plantilla_a.docx');
    expect(container.read(activeTemplateProvider).valueOrNull, isNotNull);

    await projectNotifier.createProject(name: 'Proyecto B');
    expect(container.read(activeTemplateProvider).valueOrNull, isNull);

    await templateNotifier.importTemplate(filePath: '/tmp/plantilla_b.docx');
    expect(container.read(activeTemplateProvider).valueOrNull, isNotNull);

    await projectNotifier.closeProject();
    expect(container.read(activeTemplateProvider).valueOrNull, isNull);
  });

  test(
    'una importación que resuelve tras cambiar de proyecto no se aplica',
    () async {
      final pendingLoad = Completer<Template>();
      final fakeTemplateRepository = FakeTemplateRepository(
        loadHandler: (_) => pendingLoad.future,
      );
      final container = _createContainer(fakeTemplateRepository);
      addTearDown(container.dispose);

      final projectNotifier = container.read(activeProjectProvider.notifier);
      final templateNotifier = container.read(activeTemplateProvider.notifier);

      await projectNotifier.createProject(name: 'Proyecto A');
      final importFuture = templateNotifier.importTemplate(
        filePath: '/tmp/plantilla_lenta.docx',
      );

      await projectNotifier.createProject(name: 'Proyecto B');
      pendingLoad.complete(
        Template(
          sourcePath: '/tmp/plantilla_lenta.docx',
          fileName: 'plantilla_lenta.docx',
          fileSizeBytes: 10,
          importedAt: DateTime.utc(2026),
        ),
      );
      await importFuture;

      expect(container.read(activeTemplateProvider).valueOrNull, isNull);
    },
  );

  test('solo la importación más reciente se aplica cuando resuelven fuera de '
      'orden', () async {
    final firstLoad = Completer<Template>();
    final secondLoad = Completer<Template>();
    var callCount = 0;
    final fakeTemplateRepository = FakeTemplateRepository(
      loadHandler: (_) {
        callCount++;
        return callCount == 1 ? firstLoad.future : secondLoad.future;
      },
    );
    final container = _createContainer(fakeTemplateRepository);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto');
    final templateNotifier = container.read(activeTemplateProvider.notifier);

    final firstImport = templateNotifier.importTemplate(
      filePath: '/tmp/primera.docx',
    );
    final secondImport = templateNotifier.importTemplate(
      filePath: '/tmp/segunda.docx',
    );

    secondLoad.complete(
      Template(
        sourcePath: '/tmp/segunda.docx',
        fileName: 'segunda.docx',
        fileSizeBytes: 10,
        importedAt: DateTime.utc(2026),
      ),
    );
    await secondImport;
    firstLoad.complete(
      Template(
        sourcePath: '/tmp/primera.docx',
        fileName: 'primera.docx',
        fileSizeBytes: 10,
        importedAt: DateTime.utc(2026),
      ),
    );
    await firstImport;

    expect(
      container.read(activeTemplateProvider).valueOrNull?.fileName,
      'segunda.docx',
    );
  });
}

ProviderContainer _createContainer(FakeTemplateRepository templateRepository) {
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
