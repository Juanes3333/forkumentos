import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/theme/app_theme.dart';
import 'package:forkumentos/features/mapping/domain/header_mismatch.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/header_mismatch_dialog.dart';

void main() {
  const mismatches = <HeaderMismatch>[
    HeaderMismatch(
      fieldIndex: 3,
      expectedHeader: 'Tipo y numero - CC',
      actualHeader: 'cedulaContratista',
      affectedAssignmentIds: <String>['a'],
    ),
  ];

  Future<HeaderMismatchAction?> pressAndResolve(
    WidgetTester tester,
    String buttonLabel,
  ) async {
    HeaderMismatchAction? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showHeaderMismatchDialog(
                context: context,
                mismatches: mismatches,
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('D'), findsOneWidget);
    expect(find.text('Tipo y numero - CC'), findsOneWidget);
    expect(find.text('cedulaContratista'), findsOneWidget);

    await tester.tap(find.text(buttonLabel));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Aceptar y actualizar devuelve acceptAndUpdate', (tester) async {
    expect(
      await pressAndResolve(tester, 'Aceptar y actualizar'),
      HeaderMismatchAction.acceptAndUpdate,
    );
  });

  testWidgets('Omitir devuelve skip', (tester) async {
    expect(await pressAndResolve(tester, 'Omitir'), HeaderMismatchAction.skip);
  });

  testWidgets('Cancelar devuelve cancel', (tester) async {
    expect(
      await pressAndResolve(tester, 'Cancelar'),
      HeaderMismatchAction.cancel,
    );
  });

  test('excelColumnLetter convierte índices a letras', () {
    expect(excelColumnLetter(0), 'A');
    expect(excelColumnLetter(3), 'D');
    expect(excelColumnLetter(25), 'Z');
    expect(excelColumnLetter(26), 'AA');
  });
}
