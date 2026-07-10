import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/project/presentation/confirm_discard_project_changes_dialog.dart';

void main() {
  testWidgets('confirma descarte cuando el usuario presiona Continuar', (
    WidgetTester tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                result = await confirmDiscardProjectChanges(context);
              },
              child: const Text('Abrir diálogo'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir diálogo'));
    await tester.pumpAndSettle();

    expect(find.text('Proyecto sin guardar'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('descarta la confirmación cuando el usuario presiona Cancelar', (
    WidgetTester tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                result = await confirmDiscardProjectChanges(context);
              },
              child: const Text('Abrir diálogo'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir diálogo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
