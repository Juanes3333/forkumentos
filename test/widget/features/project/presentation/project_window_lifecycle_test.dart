import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/project/presentation/confirm_close_project_dialog.dart';
import 'package:forkumentos/features/project/presentation/project_window_lifecycle.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../../../support/fakes.dart';

void main() {
  testWidgets(
    'sincroniza el título sin proyecto activo y al crear uno con cambios '
    'sin guardar',
    (WidgetTester tester) async {
      final windowService = FakeWindowService();
      final container = _buildContainer(windowService);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProjectWindowLifecycle(child: SizedBox()),
          ),
        ),
      );

      expect(windowService.lastTitle, 'Forkumentos');
      expect(windowService.preventCloseActive, isTrue);

      await container
          .read(activeProjectProvider.notifier)
          .createProject(name: 'Proyecto Demo');
      await tester.pump();

      expect(windowService.lastTitle, 'Forkumentos — Proyecto Demo *');
    },
  );

  testWidgets('limpia el indicador de cambios sin guardar tras guardar', (
    WidgetTester tester,
  ) async {
    final windowService = FakeWindowService();
    final container = _buildContainer(windowService);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProjectWindowLifecycle(child: SizedBox()),
        ),
      ),
    );

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Demo');
    await container
        .read(activeProjectProvider.notifier)
        .saveProject(filePath: '/tmp/proyecto-demo.fork');
    await tester.pump();

    expect(windowService.lastTitle, 'Forkumentos — Proyecto Demo');
  });

  testWidgets(
    'cierra la ventana inmediatamente cuando no hay cambios sin guardar',
    (WidgetTester tester) async {
      final windowService = FakeWindowService();
      final container = _buildContainer(windowService);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProjectWindowLifecycle(child: SizedBox()),
          ),
        ),
      );

      await windowService.registeredCloseListener!();

      expect(windowService.destroyed, isTrue);
    },
  );

  testWidgets('pide confirmación al cerrar con cambios y respeta cancelar', (
    WidgetTester tester,
  ) async {
    final windowService = FakeWindowService();
    final container = _buildContainer(windowService);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Demo');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProjectWindowLifecycle(child: SizedBox()),
        ),
      ),
    );

    unawaited(windowService.registeredCloseListener!());
    await tester.pumpAndSettle();

    expect(find.text('Proyecto sin guardar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(windowService.destroyed, isFalse);
  });

  testWidgets('permite cerrar sin guardar desde el diálogo de cierre', (
    WidgetTester tester,
  ) async {
    final windowService = FakeWindowService();
    final container = _buildContainer(windowService);
    addTearDown(container.dispose);

    await container
        .read(activeProjectProvider.notifier)
        .createProject(name: 'Proyecto Demo');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProjectWindowLifecycle(child: SizedBox()),
        ),
      ),
    );

    unawaited(windowService.registeredCloseListener!());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cerrar sin guardar'));
    await tester.pumpAndSettle();

    expect(windowService.destroyed, isTrue);
  });

  testWidgets('confirmCloseProject devuelve guardar y cerrar', (
    WidgetTester tester,
  ) async {
    late CloseProjectChoice choice;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                choice = await confirmCloseProject(context);
              },
              child: const Text('abrir'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar y cerrar'));
    await tester.pumpAndSettle();

    expect(choice, CloseProjectChoice.saveAndClose);
  });
}

ProviderContainer _buildContainer(FakeWindowService windowService) {
  return ProviderContainer(
    overrides: <Override>[
      loggingServiceProvider.overrideWithValue(FakeLoggingService()),
      projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
      windowServiceProvider.overrideWithValue(windowService),
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
