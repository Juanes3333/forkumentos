import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/project/presentation/confirm_open_project_dialog.dart';

void main() {
  Future<OpenProjectChoice> showAndTap(
    WidgetTester tester,
    String buttonLabel,
  ) async {
    late OpenProjectChoice result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await confirmOpenProject(context);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(buttonLabel));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('"Abrir aquí" devuelve openHere', (tester) async {
    expect(await showAndTap(tester, 'Abrir aquí'), OpenProjectChoice.openHere);
  });

  testWidgets('"Abrir en nueva ventana" devuelve newWindow', (tester) async {
    expect(
      await showAndTap(tester, 'Abrir en nueva ventana'),
      OpenProjectChoice.newWindow,
    );
  });

  testWidgets('"Cancelar" devuelve cancel', (tester) async {
    expect(await showAndTap(tester, 'Cancelar'), OpenProjectChoice.cancel);
  });

  testWidgets('descartar el diálogo (barrier) devuelve cancel', (tester) async {
    late OpenProjectChoice result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await confirmOpenProject(context);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, OpenProjectChoice.cancel);
  });
}
