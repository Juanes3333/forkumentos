import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/workspace/workspace_paths.dart';
import 'package:forkumentos/routing/workbench/template_tab_bar.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

import '../../../support/fakes.dart';

void main() {
  late Directory root;
  late ProviderContainer container;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('forkumentos_tabs_test_');
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

  File docx(String name) => File(p.join(root.path, 'src', name))
    ..createSync(recursive: true)
    ..writeAsStringSync(name);

  /// Proyecto con las plantillas dadas (la última queda activa). Usa
  /// `runAsync` porque copiar archivos es E/S real.
  Future<void> openProjectWith(
    WidgetTester tester,
    List<String> templates,
  ) async {
    await tester.runAsync(() async {
      final notifier = container.read(activeProjectProvider.notifier);
      await notifier.createProject(name: 'Paquete');
      for (final name in templates) {
        await notifier.addTemplate(sourcePath: docx(name).path);
      }
    });
  }

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TemplateTabBar())),
      ),
    );
    await tester.pump();
  }

  String? activeId() =>
      container.read(activeProjectProvider).requireValue!.activeTemplateId;

  testWidgets('sin plantilla no muestra nada', (tester) async {
    await openProjectWith(tester, const <String>[]);
    await pumpBar(tester);

    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('con una plantilla muestra su pestaña y el botón de añadir, '
      'sin cerrar', (tester) async {
    await openProjectWith(tester, <String>['contrato.docx']);
    await pumpBar(tester);

    expect(find.text('contrato'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('con varias muestra todas, la última añadida activa, y '
      'tocar otra la activa', (tester) async {
    await openProjectWith(tester, <String>[
      'contrato.docx',
      'paz_y_salvo.docx',
    ]);
    await pumpBar(tester);

    expect(find.text('contrato'), findsOneWidget);
    expect(find.text('paz_y_salvo'), findsOneWidget);
    final tabs = container.read(templateTabsProvider);
    expect(tabs.map((tab) => tab.isActive), <bool>[false, true]);

    await tester.tap(find.text('contrato'));
    await tester.pump();

    expect(
      container.read(templateTabsProvider).map((tab) => tab.isActive),
      <bool>[true, false],
    );
  });

  testWidgets('quitar una pestaña pide confirmar y deja la otra', (
    tester,
  ) async {
    await openProjectWith(tester, <String>[
      'contrato.docx',
      'paz_y_salvo.docx',
    ]);
    await pumpBar(tester);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('Quitar plantilla'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Quitar'));
    await tester.pumpAndSettle();

    final project = container.read(activeProjectProvider).requireValue!;
    expect(project.templates, isEmpty);
    expect(project.embeddedTemplatePath, endsWith('paz_y_salvo.docx'));
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('cancelar al quitar no cambia nada', (tester) async {
    await openProjectWith(tester, <String>[
      'contrato.docx',
      'paz_y_salvo.docx',
    ]);
    await pumpBar(tester);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(
      container.read(activeProjectProvider).requireValue!.templates,
      hasLength(2),
    );
  });

  testWidgets('cycleTemplate recorre las pestañas y da la vuelta', (
    tester,
  ) async {
    await openProjectWith(tester, <String>[
      'contrato.docx',
      'paz_y_salvo.docx',
      'acta.docx',
    ]);
    await pumpBar(tester);
    final ids = container
        .read(activeProjectProvider)
        .requireValue!
        .templates
        .map((t) => t.id)
        .toList();
    expect(activeId(), ids[2]);

    final element = tester.element(find.byType(TemplateTabBar));
    final ref = ProviderScope.containerOf(element);
    expect(ref, same(container));

    // cycleTemplate necesita un WidgetRef: se prueba desde un consumidor.
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    cycleTemplate(widgetRef, 1);
    expect(activeId(), ids[0]);
    cycleTemplate(widgetRef, -1);
    expect(activeId(), ids[2]);
    cycleTemplate(widgetRef, -1);
    expect(activeId(), ids[1]);
  });
}
