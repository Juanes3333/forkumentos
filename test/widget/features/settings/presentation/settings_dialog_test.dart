import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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
  }) {
    return ProviderScope(
      overrides: <Override>[
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
                onPressed: () => showSettingsDialog(context),
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

    testWidgets('con cambios sin guardar no descarga', (
      WidgetTester tester,
    ) async {
      final installer = _FakeUpdateInstaller();
      await openAboutTab(
        tester,
        createWidget(updateResult: _updateWithInstaller, installer: installer),
      );
      // Un proyecto recién creado queda con cambios sin guardar.
      await ProviderScope.containerOf(
        tester.element(find.text('Actualizar ahora')),
      ).read(activeProjectProvider.notifier).createProject(name: 'Proyecto');
      await tester.pump();

      await tester.tap(find.text('Actualizar ahora'));
      await tester.pump();

      expect(find.textContaining('Guarda el proyecto'), findsOneWidget);
      expect(installer.onProgress, isNull);
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
