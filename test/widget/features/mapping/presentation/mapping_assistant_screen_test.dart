import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/document_viewer/data/document_repository_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_assistant_screen.dart';
import 'package:forkumentos/features/template/data/template_repository_provider.dart';

import '../../../../support/fakes.dart';

void main() {
  testWidgets('muestra estado vacío sin plantilla activa', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          documentRepositoryProvider.overrideWithValue(
            FakeDocumentRepository(),
          ),
        ],
        child: const MaterialApp(
          home: MappingAssistantScreen(
            documentPath: null,
            headers: <String>['nombre'],
            previewRow: <String?>['Ana'],
            isSourceLoading: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Importa una plantilla y una fuente de datos para mapear.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra preview de primera fila del datasource', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          templateRepositoryProvider.overrideWithValue(
            FakeTemplateRepository(),
          ),
          datasourceRepositoryProvider.overrideWithValue(
            FakeDatasourceRepository(),
          ),
          documentRepositoryProvider.overrideWithValue(
            FakeDocumentRepository(),
          ),
        ],
        child: const MaterialApp(
          home: MappingAssistantScreen(
            documentPath: '/tmp/plantilla.docx',
            headers: <String>['nombre', 'correo'],
            previewRow: <String?>['Ana', 'ana@example.com'],
            isSourceLoading: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('nombre'), findsWidgets);
    expect(find.text('Ana'), findsWidgets);
    expect(find.text('correo'), findsWidgets);
  });
}
