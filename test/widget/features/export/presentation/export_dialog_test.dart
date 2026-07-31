import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/export/presentation/export_dialog.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';

void main() {
  testWidgets('"Todas las páginas" es el modo por defecto y oculta el campo', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, pageCount: 12);
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Todas las páginas (12)'), findsOneWidget);
    expect(find.text('Ej. 1-5, 8'), findsNothing);
  });

  testWidgets('"Rango personalizado" revela el campo de texto', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, pageCount: 12);
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Both the row-range and page-range sections have this option; the
    // page-range one is the second occurrence, and lives below the fold of
    // the dialog's scroll view.
    final pageCustomOption = find.text('Rango personalizado').last;
    await tester.ensureVisible(pageCustomOption);
    await tester.pumpAndSettle();
    await tester.tap(pageCustomOption);
    await tester.pumpAndSettle();

    expect(find.text('Ej. 1-5, 8'), findsOneWidget);
  });

  testWidgets('un rango de páginas inválido muestra un error y no cierra', (
    WidgetTester tester,
  ) async {
    ExportDialogResult? result;
    await _pumpDialog(
      tester,
      pageCount: 12,
      onResult: (value) => result = value,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final pageCustomOption = find.text('Rango personalizado').last;
    await tester.ensureVisible(pageCustomOption);
    await tester.pumpAndSettle();
    await tester.tap(pageCustomOption);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ej. 1-5, 8'), 'x');
    await tester.tap(find.widgetWithText(FilledButton, 'Exportar'));
    await tester.pumpAndSettle();

    expect(find.text('Número de fila inválido: "x".'), findsOneWidget);
    expect(result, isNull);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required int pageCount,
  void Function(ExportDialogResult?)? onResult,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        defaultExportFormatProvider.overrideWithValue('docx'),
        defaultCreateZipProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await ExportDialog.show(
                  context,
                  destinationFolder: 'C:/exports',
                  headers: const <String>['Nombre'],
                  sampleRow: const <String?>['Ana'],
                  rowCount: 5,
                  currentRowIndex: 0,
                  missingFieldHeaders: const <String>[],
                  pageCount: pageCount,
                );
                onResult?.call(result);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
}
