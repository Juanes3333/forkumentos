import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/field_reconciliation_dialog.dart';
import 'package:forkumentos/routing/workbench/field_reconciliation_host.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';

import '../../../support/fakes.dart';

void main() {
  late List<String> headers;
  late ProviderContainer container;
  var imports = 0;

  setUp(() {
    imports = 0;
    headers = <String>['nombre', 'cédula'];
    container = ProviderContainer(
      overrides: <Override>[
        loggingServiceProvider.overrideWithValue(FakeLoggingService()),
        datasourceRepositoryProvider.overrideWithValue(
          FakeDatasourceRepository(
            loadHandler: (path) async => Datasource(
              sourcePath: path,
              fileName: path,
              fileSizeBytes: 1,
              importedAt: DateTime.utc(2026),
              format: DatasourceFormat.csv,
              headers: headers,
              previewRow: List<String?>.filled(headers.length, null),
              rowCount: 1,
              emptyColumnIndexes: const <int>[],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> replaceColumns(List<String> next) async {
    headers = next;
    imports++;
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: 'datos_$imports.csv');
  }

  Future<void> mapTwoFields() async {
    await replaceColumns(<String>['nombre', 'cédula']);
    final mapping = container.read(activeMappingProvider.notifier);
    for (final (index, text) in <(int, String)>[(0, 'Ana'), (1, 'Perez')]) {
      mapping.confirmAssignment(
        selection: DocumentTextSelection(
          path: const DocumentTextPath(
            steps: <DocumentPathStep>[
              DocumentPathStep.rootBlock(blockIndex: 0),
            ],
          ),
          startOffset: index * 20,
          endOffset: index * 20 + text.length,
          selectedText: text,
        ),
        fieldHeader: headers[index],
        fieldIndex: index,
        headerCount: 2,
      );
    }
  }

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FieldReconciliationHost(child: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('abre el diálogo solo cuando aparece un campo sin columna', (
    tester,
  ) async {
    await mapTwoFields();
    await pumpHost(tester);
    expect(find.byType(FieldReconciliationDialog), findsNothing);

    await replaceColumns(<String>['nombre', 'otra']);
    await tester.pumpAndSettle();

    expect(find.byType(FieldReconciliationDialog), findsOneWidget);
    expect(find.textContaining('«cédula»'), findsOneWidget);
  });

  testWidgets('un proyecto que se abre con campos sin columna lo muestra', (
    tester,
  ) async {
    await mapTwoFields();
    await replaceColumns(<String>['nombre', 'otra']);

    await pumpHost(tester);

    expect(find.byType(FieldReconciliationDialog), findsOneWidget);
  });

  testWidgets('no vuelve a abrirse por un campo que se dejó para después', (
    tester,
  ) async {
    await mapTwoFields();
    await pumpHost(tester);
    await replaceColumns(<String>['nombre', 'otra']);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolver después'));
    await tester.pumpAndSettle();

    // Un refresco más con el mismo campo todavía sin columna.
    await replaceColumns(<String>['nombre', 'otra', 'extra']);
    await tester.pumpAndSettle();

    expect(find.byType(FieldReconciliationDialog), findsNothing);
  });

  testWidgets('un campo nuevo sin columna sí abre el diálogo otra vez', (
    tester,
  ) async {
    await mapTwoFields();
    await pumpHost(tester);
    await replaceColumns(<String>['nombre', 'otra']);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolver después'));
    await tester.pumpAndSettle();

    // Ahora también desaparece "nombre".
    await replaceColumns(<String>['otra']);
    await tester.pumpAndSettle();

    expect(find.byType(FieldReconciliationDialog), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);
  });
}
