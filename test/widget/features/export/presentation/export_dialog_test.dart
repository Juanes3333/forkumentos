import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/export/domain/export_job.dart';
import 'package:forkumentos/features/export/presentation/export_dialog.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';

void main() {
  group('advertencia de campos sin asignar', () {
    testWidgets('se muestra cuando hay campos sin mapear', (
      WidgetTester tester,
    ) async {
      await _pumpDialog(
        tester,
        missingFieldHeaders: const <String>['Apellido'],
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Hay campos sin asignar: Apellido'),
        findsOneWidget,
      );
    });

    testWidgets(
      'bloquea el botón Exportar hasta marcar "Continuar de todos modos"',
      (WidgetTester tester) async {
        ExportDialogResult? result;
        await _pumpDialog(
          tester,
          missingFieldHeaders: const <String>['Apellido'],
          onResult: (value) => result = value,
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Exportar'));
        await tester.pumpAndSettle();
        expect(result, isNull);

        await tester.tap(
          find.widgetWithText(CheckboxListTile, 'Continuar de todos modos'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Exportar'));
        await tester.pumpAndSettle();

        expect(result, isNotNull);
      },
    );

    testWidgets('no aparece cuando todos los campos están asignados', (
      WidgetTester tester,
    ) async {
      await _pumpDialog(tester);
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hay campos sin asignar'), findsNothing);
    });
  });

  group('rango de filas', () {
    testWidgets('"Fila actual" es el modo por defecto', (
      WidgetTester tester,
    ) async {
      await _pumpDialog(tester, currentRowIndex: 2);
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Fila actual (fila 3)'), findsOneWidget);
      expect(find.text('Ej. 1-20,15,18-25'), findsNothing);
    });

    testWidgets('"Rango personalizado" revela el campo de texto', (
      WidgetTester tester,
    ) async {
      await _pumpDialog(tester);
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rango personalizado'));
      await tester.pumpAndSettle();

      expect(find.text('Ej. 1-20,15,18-25'), findsOneWidget);
    });

    testWidgets('un rango de filas inválido muestra un error y no cierra', (
      WidgetTester tester,
    ) async {
      ExportDialogResult? result;
      await _pumpDialog(tester, onResult: (value) => result = value);
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rango personalizado'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Ej. 1-20,15,18-25'),
        'x',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Exportar'));
      await tester.pumpAndSettle();

      expect(find.text('Número de fila inválido: "x".'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('"Todas las filas" exporta el conjunto completo', (
      WidgetTester tester,
    ) async {
      ExportDialogResult? result;
      await _pumpDialog(tester, onResult: (value) => result = value);
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Todas las filas (5)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Exportar'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.job.rangeMode, ExportRangeMode.batch);
      expect(result!.job.rowIndexes, <int>[0, 1, 2, 3, 4]);
    });
  });

  testWidgets('el checkbox de ZIP inicia con el valor por defecto y viaja '
      'en el job', (WidgetTester tester) async {
    ExportDialogResult? result;
    await _pumpDialog(
      tester,
      createZipDefault: true,
      onResult: (value) => result = value,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final checkbox = tester.widget<CheckboxListTile>(
      find.widgetWithText(
        CheckboxListTile,
        'Crear ZIP con los archivos generados',
      ),
    );
    expect(checkbox.value, isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Exportar'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.job.createZip, isTrue);
  });

  testWidgets('el patrón de nombre de archivo se aplica al job por defecto', (
    WidgetTester tester,
  ) async {
    ExportDialogResult? result;
    await _pumpDialog(
      tester,
      headers: const <String>['Nombre', 'Apellido'],
      onResult: (value) => result = value,
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Exportar'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.job.filenamePattern.blocks, hasLength(1));
    expect(result!.job.destinationFolder, 'C:/exports');
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  List<String> headers = const <String>['Nombre'],
  List<String> missingFieldHeaders = const <String>[],
  int rowCount = 5,
  int currentRowIndex = 0,
  bool createZipDefault = false,
  void Function(ExportDialogResult?)? onResult,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        defaultCreateZipProvider.overrideWithValue(createZipDefault),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await ExportDialog.show(
                  context,
                  destinationFolder: 'C:/exports',
                  headers: headers,
                  sampleRow: List<String?>.filled(headers.length, 'Ana'),
                  rowCount: rowCount,
                  currentRowIndex: currentRowIndex,
                  missingFieldHeaders: missingFieldHeaders,
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
