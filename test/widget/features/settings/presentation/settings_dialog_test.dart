import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/settings/data/update_checker.dart';
import 'package:forkumentos/features/settings/domain/app_settings.dart';
import 'package:forkumentos/features/settings/presentation/settings_dialog.dart';
import 'package:forkumentos/features/settings/presentation/update_check_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';
import 'package:forkumentos/shared/widgets/about_forkumentos_dialog.dart';

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

void main() {
  Widget createWidget({UpdateCheckResult? updateResult}) {
    return ProviderScope(
      overrides: <Override>[
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
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
        expect(find.text('Descargar actualización'), findsOneWidget);
      },
    );
  });
}
