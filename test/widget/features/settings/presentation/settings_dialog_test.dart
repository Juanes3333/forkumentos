import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/settings/data/update_checker.dart';
import 'package:forkumentos/features/settings/domain/app_settings.dart';
import 'package:forkumentos/features/settings/presentation/settings_dialog.dart';
import 'package:forkumentos/features/settings/presentation/update_check_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';
import 'package:forkumentos/shared/widgets/about_forkumentos_dialog.dart';

import '../../../../support/fakes.dart';

final class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return AppSettings.defaults(workspaceRoot: 'C:/dummy');
  }
}

final class _FakeUpdateCheckNotifier extends UpdateCheckNotifier {
  _FakeUpdateCheckNotifier({this.initialResult});

  final UpdateCheckResult? initialResult;

  @override
  Future<UpdateCheckResult?> build() async {
    return initialResult;
  }
}

final class _FakeUpdateInstaller implements UpdateInstaller {
  final Completer<File> downloadCompleter = Completer<File>();
  void Function(int received, int total)? onProgress;
  File? launched;

  @override
  Future<File> download({
    required String downloadUrl,
    required String version,
    void Function(int received, int total)? onProgress,
  }) {
    this.onProgress = onProgress;
    return downloadCompleter.future;
  }

  @override
  Future<void> launchAndExit(File installer) async {
    launched = installer;
  }
}

const _updateWithInstaller = UpdateCheckResult(
  currentVersion: '1.6.0',
  latestVersion: '1.7.0',
  isUpdateAvailable: true,
  downloadUrl: 'https://example.com/ForkumentosSetup.exe',
);

void main() {
  Widget createWidget({
    UpdateCheckResult? updateResult,
    UpdateInstaller? installer,
    Future<bool> Function()? onSaveProject,
    bool noWorkspace = false,
  }) {
    return ProviderScope(
      overrides: <Override>[
        if (noWorkspace) workspacePathsProvider.overrideWithValue(null),
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        loggingServiceProvider.overrideWithValue(FakeLoggingService()),
        if (installer != null)
          updateInstallerProvider.overrideWithValue(installer),
        if (updateResult != null)
          updateCheckProvider.overrideWith(
            () => _FakeUpdateCheckNotifier(initialResult: updateResult),
          ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () =>
                    showSettingsDialog(context, onSaveProject: onSaveProject),
                child: const Text('Open Settings'),
              );
            },
          ),
        ),
      ),
    );
  }

  group('SettingsDialog', () {
    testWidgets('renders all 5 tabs including Acerca de', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Apariencia'), findsOneWidget);
      expect(find.text('Comportamiento'), findsOneWidget);
      expect(find.text('Exportación'), findsOneWidget);
      expect(find.text('Acerca de'), findsOneWidget);
    });

    testWidgets('Acerca de tab displays version and check button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Acerca de'));
      await tester.pumpAndSettle();

      expect(find.text('Versión $forkumentosVersion'), findsOneWidget);
      expect(find.text('Buscar actualizaciones'), findsOneWidget);
    });

    testWidgets(
      'Acerca de tab displays up to date message when no update available',
      (WidgetTester tester) async {
        const result = UpdateCheckResult(
          currentVersion: '1.6.0',
          latestVersion: '1.6.0',
          isUpdateAvailable: false,
        );

        await tester.pumpWidget(createWidget(updateResult: result));
        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Acerca de'));
        await tester.pumpAndSettle();

        expect(find.text('Estás al día'), findsOneWidget);
        expect(
          find.text(
            'Tienes la última versión disponible ($forkumentosVersion).',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Acerca de tab displays update available card when newer version exists',
      (WidgetTester tester) async {
        const result = UpdateCheckResult(
          currentVersion: '1.6.0',
          latestVersion: '1.7.0',
          isUpdateAvailable: true,
          releaseNotes: 'Mejoras en el exportador DOCX.',
          downloadUrl:
              'https://github.com/Juanes3333/forkumentos/releases/download/v1.7.0/ForkumentosSetup.exe',
        );

        await tester.pumpWidget(createWidget(updateResult: result));
        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Acerca de'));
        await tester.pumpAndSettle();

        expect(find.text('¡Nueva versión disponible!'), findsOneWidget);
        expect(find.text('Disponible: 1.7.0'), findsOneWidget);
        expect(find.text('Mejoras en el exportador DOCX.'), findsOneWidget);
        expect(find.text('Actualizar ahora'), findsOneWidget);
      },
    );

    Future<void> openAboutTab(WidgetTester tester, Widget widget) async {
      await tester.pumpWidget(widget);
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acerca de'));
      await tester.pumpAndSettle();
    }

    VoidCallback? updateButtonCallback(WidgetTester tester) {
      return tester
          .widget<ButtonStyleButton>(
            find.ancestor(
              of: find.text('Actualizar ahora'),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            ),
          )
          .onPressed;
    }

    testWidgets(
      'Actualizar ahora descarga con progreso y lanza el instalador',
      (WidgetTester tester) async {
        final installer = _FakeUpdateInstaller();
        await openAboutTab(
          tester,
          createWidget(
            updateResult: _updateWithInstaller,
            installer: installer,
          ),
        );

        await tester.tap(find.text('Actualizar ahora'));
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('Descargando actualización...'), findsOneWidget);

        installer.onProgress!(50, 200);
        await tester.pump();
        expect(find.text('Descargando actualización... 25%'), findsOneWidget);
        expect(updateButtonCallback(tester), isNull);

        final file = File('instalador.exe');
        installer.downloadCompleter.complete(file);
        await tester.pump();
        expect(installer.launched, same(file));
      },
    );

    testWidgets('un fallo de descarga muestra el error y permite reintentar', (
      WidgetTester tester,
    ) async {
      final installer = _FakeUpdateInstaller();
      await openAboutTab(
        tester,
        createWidget(updateResult: _updateWithInstaller, installer: installer),
      );

      await tester.tap(find.text('Actualizar ahora'));
      await tester.pump();
      installer.downloadCompleter.completeError(
        const HttpException('HTTP 500'),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No se pudo descargar la actualización'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(installer.launched, isNull);
      expect(updateButtonCallback(tester), isNotNull);
    });

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.text('Actualizar ahora')),
        );

    // Un proyecto recién creado queda con cambios sin guardar.
    Future<void> makeProjectDirty(WidgetTester tester) async {
      await containerOf(
        tester,
      ).read(activeProjectProvider.notifier).createProject(name: 'Proyecto');
      await tester.pump();
    }

    testWidgets('con cambios sin guardar pregunta y Cancelar no descarga', (
      WidgetTester tester,
    ) async {
      final installer = _FakeUpdateInstaller();
      await openAboutTab(
        tester,
        createWidget(updateResult: _updateWithInstaller, installer: installer),
      );
      await makeProjectDirty(tester);

      await tester.tap(find.text('Actualizar ahora'));
      await tester.pumpAndSettle();
      expect(find.text('Hay cambios sin guardar'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(installer.onProgress, isNull);
      expect(installer.launched, isNull);
    });

    testWidgets('Guardar y actualizar guarda y luego descarga', (
      WidgetTester tester,
    ) async {
      final installer = _FakeUpdateInstaller();
      late ProviderContainer container;
      var saves = 0;
      await openAboutTab(
        tester,
        createWidget(
          updateResult: _updateWithInstaller,
          installer: installer,
          // Sin rutas de workspace, cerrar el proyecto no toca el disco real
          // (que no completa dentro de testWidgets).
          noWorkspace: true,
          onSaveProject: () async {
            saves++;
            await container.read(activeProjectProvider.notifier).closeProject();
            return true;
          },
        ),
      );
      container = containerOf(tester);
      await makeProjectDirty(tester);

      await tester.tap(find.text('Actualizar ahora'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar y actualizar'));
      // Tras guardar empieza la descarga y su barra indeterminada anima sin
      // parar, así que no se puede esperar a que se asiente.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(saves, 1);
      expect(installer.onProgress, isNotNull);
    });

    testWidgets('si el guardado falla no descarga y lo explica', (
      WidgetTester tester,
    ) async {
      final installer = _FakeUpdateInstaller();
      await openAboutTab(
        tester,
        createWidget(
          updateResult: _updateWithInstaller,
          installer: installer,
          onSaveProject: () async => false,
        ),
      );
      await makeProjectDirty(tester);

      await tester.tap(find.text('Actualizar ahora'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar y actualizar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo guardar'), findsOneWidget);
      expect(installer.onProgress, isNull);
    });

    testWidgets('editar durante la descarga pide guardar antes de lanzar', (
      WidgetTester tester,
    ) async {
      final installer = _FakeUpdateInstaller();
      await openAboutTab(
        tester,
        createWidget(updateResult: _updateWithInstaller, installer: installer),
      );

      await tester.tap(find.text('Actualizar ahora'));
      await tester.pump();
      await makeProjectDirty(tester);
      installer.downloadCompleter.complete(File('instalador.exe'));
      await tester.pumpAndSettle();

      expect(find.text('Hay cambios sin guardar'), findsOneWidget);
      expect(installer.launched, isNull);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(installer.launched, isNull);
      expect(find.text('Instalar actualización descargada'), findsOneWidget);
    });

    testWidgets('reabrir Ajustes durante la descarga no inicia otra', (
      WidgetTester tester,
    ) async {
      final installer = _FakeUpdateInstaller();
      await openAboutTab(
        tester,
        createWidget(updateResult: _updateWithInstaller, installer: installer),
      );
      await tester.tap(find.text('Actualizar ahora'));
      await tester.pump();

      // La barra indeterminada anima sin parar: no se puede usar
      // pumpAndSettle mientras dura la descarga.
      const step = Duration(seconds: 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(step);
      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      await tester.pump(step);
      await tester.tap(find.text('Acerca de'));
      await tester.pump();
      await tester.pump(step);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(updateButtonCallback(tester), isNull);
    });

    testWidgets('sin instalador .exe ofrece abrir la página del release', (
      WidgetTester tester,
    ) async {
      await openAboutTab(
        tester,
        createWidget(
          updateResult: const UpdateCheckResult(
            currentVersion: '1.6.0',
            latestVersion: '1.7.0',
            isUpdateAvailable: true,
            htmlUrl: 'https://github.com/Juanes3333/forkumentos/releases',
          ),
        ),
      );

      expect(find.text('Ver en GitHub'), findsOneWidget);
      expect(find.text('Actualizar ahora'), findsNothing);
    });
  });
}
