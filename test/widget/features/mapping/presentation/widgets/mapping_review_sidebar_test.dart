import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/mapping_review_sidebar.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

void main() {
  Future<void> pumpSidebar(
    WidgetTester tester,
    String fieldHeader, {
    int fieldIndex = 0,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MappingReviewSidebar(
            headers: const <String>['cedulaContratista'],
            previewRow: const <String?>['123'],
            assignments: <FieldAssignment>[
              FieldAssignment(
                id: 'a',
                fieldIndex: fieldIndex,
                fieldHeader: fieldHeader,
                selectedText: 'x',
                path: const DocumentTextPath(
                  steps: <DocumentPathStep>[
                    DocumentPathStep.rootBlock(blockIndex: 0),
                  ],
                ),
                startOffset: 0,
                endOffset: 1,
              ),
            ],
            onRemoveAssignment: (_) {},
            onNavigateToAssignment: (_) {},
            onNavigateToField: (_) {},
            onFieldHoverChanged: (_) {},
            onSetAssignmentIsListField:
                ({required assignmentId, required isListField}) {},
            onDefineRangeEnd: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('avisa cuando las asignaciones esperan otro encabezado', (
    tester,
  ) async {
    await pumpSidebar(tester, 'Tipo y numero - CC');

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(
      find.text('Encabezado no coincide (esperaba "Tipo y numero - CC")'),
      findsOneWidget,
    );
  });

  testWidgets('muestra arriba los campos sin columna', (tester) async {
    await pumpSidebar(tester, 'cédula', fieldIndex: -1);

    expect(find.text('1 campo sin columna'), findsOneWidget);
    expect(find.text('cédula'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Resolver'), findsOneWidget);
  });

  testWidgets('no avisa cuando el encabezado coincide', (tester) async {
    await pumpSidebar(tester, 'cedulaContratista');

    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.textContaining('Encabezado no coincide'), findsNothing);
  });
}
