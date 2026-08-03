import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/text_occurrence.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/multiple_occurrences_dialog.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  final occurrences = <TextOccurrence>[
    _occurrence(pageIndex: 1, text: 'uno'),
    _occurrence(pageIndex: 2, text: 'dos'),
  ];

  testWidgets('el ícono de cerrar aborta todo (pop null)', (
    WidgetTester tester,
  ) async {
    final result = await _showAndAct(
      tester,
      occurrences: occurrences,
      act: (tester) => tester.tap(find.byIcon(Icons.close)),
    );

    expect(result, isNull);
  });

  testWidgets('"Solo la actual" confirma la primaria sin extras (pop [])', (
    WidgetTester tester,
  ) async {
    final result = await _showAndAct(
      tester,
      occurrences: occurrences,
      act: (tester) => tester.tap(find.text('Solo la actual')),
    );

    expect(result, isEmpty);
  });

  testWidgets('"Asignar seleccionadas" respeta los checkboxes marcados', (
    WidgetTester tester,
  ) async {
    final result = await _showAndAct(
      tester,
      occurrences: occurrences,
      act: (tester) async {
        // Desmarca la primera ocurrencia; ambas empiezan marcadas.
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Asignar seleccionadas'));
      },
    );

    expect(result, hasLength(1));
    expect(result!.single.matchedText, 'dos');
  });

  testWidgets('"Asignar todas" devuelve la lista completa', (
    WidgetTester tester,
  ) async {
    final result = await _showAndAct(
      tester,
      occurrences: occurrences,
      act: (tester) => tester.tap(find.text('Asignar todas')),
    );

    expect(result, occurrences);
  });
}

Future<List<TextOccurrence>?> _showAndAct(
  WidgetTester tester, {
  required List<TextOccurrence> occurrences,
  required Future<void> Function(WidgetTester tester) act,
}) async {
  List<TextOccurrence>? result;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await MultipleOccurrencesDialog.show(
                context,
                occurrences: occurrences,
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

  await act(tester);
  await tester.pumpAndSettle();

  return result;
}

TextOccurrence _occurrence({required int pageIndex, required String text}) {
  return TextOccurrence(
    path: const DocumentTextPath(
      steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 0)],
    ),
    startOffset: 0,
    endOffset: text.length,
    matchedText: text,
  );
}
