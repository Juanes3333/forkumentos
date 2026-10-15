import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/new_field_dialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required void Function(String?) onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                onResult(
                  await showNewFieldDialog(
                    context,
                    existingHeaders: const <String>['nombre', 'Cédula'],
                    selectedText: 'Pérez',
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el texto seleccionado y devuelve el nombre sin '
      'espacios sobrantes', (tester) async {
    String? result;
    await open(tester, onResult: (value) => result = value);

    expect(find.text('Texto seleccionado: «Pérez»'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Apellidos  ');
    await tester.tap(find.text('Crear campo'));
    await tester.pumpAndSettle();

    expect(result, 'Apellidos');
  });

  testWidgets('no deja continuar con un nombre vacío', (tester) async {
    String? result = 'sin tocar';
    await open(tester, onResult: (value) => result = value);

    await tester.tap(find.text('Crear campo'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un nombre para el campo.'), findsOneWidget);
    expect(result, 'sin tocar');
  });

  testWidgets('no deja repetir un campo existente aunque cambien mayúsculas, '
      'tildes o espacios', (tester) async {
    String? result = 'sin tocar';
    await open(tester, onResult: (value) => result = value);

    await tester.enterText(find.byType(TextField), '  cedula ');
    await tester.tap(find.text('Crear campo'));
    await tester.pumpAndSettle();

    expect(find.text('Ya existe un campo con ese nombre.'), findsOneWidget);
    expect(result, 'sin tocar');
  });

  testWidgets('Cancelar devuelve null', (tester) async {
    String? result = 'sin tocar';
    await open(tester, onResult: (value) => result = value);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
