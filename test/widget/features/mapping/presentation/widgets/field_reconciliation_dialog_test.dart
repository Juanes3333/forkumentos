import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/field_reconciliation_provider.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/field_reconciliation_dialog.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';

import '../../../../../support/fakes.dart';

void main() {
  late List<String> headers;
  late ProviderContainer container;

  setUp(() {
    headers = <String>['nombre', 'cédula', 'correo'];
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

  var imports = 0;
  Future<void> replaceColumns(List<String> next) async {
    headers = next;
    imports++;
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: 'datos_$imports.csv');
  }

  // Mapea tres textos a nombre, cédula y correo con las columnas iniciales.
  Future<void> mapThreeFields() async {
    final mapping = container.read(activeMappingProvider.notifier);
    await replaceColumns(<String>['nombre', 'cédula', 'correo']);
    for (final (index, text) in <(int, String)>[
      (0, 'Ana'),
      (1, 'Perez'),
      (2, 'ana@x.co'),
    ]) {
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
        headerCount: 3,
      );
    }
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showFieldReconciliationDialog(context),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  List<int> indexes() => container
      .read(activeMappingProvider)
      .state
      .assignments
      .map((a) => a.fieldIndex)
      .toList();

  testWidgets(
    'muestra el campo, el contador y propone la única columna libre',
    (tester) async {
      await mapThreeFields();
      // "cédula" desaparece y aparece "número de documento".
      await replaceColumns(<String>['nombre', 'número de documento', 'correo']);

      await openDialog(tester);

      expect(find.textContaining('«cédula»'), findsOneWidget);
      expect(find.text('Se usa en 1 lugar del documento.'), findsOneWidget);
      // Con un solo campo no hay contador.
      expect(find.byTooltip('Campo siguiente'), findsNothing);
      expect(
        find.textContaining('Sugerencia: «número de documento»'),
        findsOneWidget,
      );
      expect(find.text('B · número de documento'), findsOneWidget);
    },
  );

  testWidgets('"Es este campo" reasigna el campo y cierra al resolver el '
      'último', (tester) async {
    await mapThreeFields();
    await replaceColumns(<String>['nombre', 'número de documento', 'correo']);
    await openDialog(tester);

    await tester.tap(find.text('Es este campo'));
    await tester.pumpAndSettle();

    expect(indexes(), <int>[0, 1, 2]);
    final renamed = container.read(activeMappingProvider).state.assignments[1];
    expect(renamed.fieldHeader, 'número de documento');
    expect(find.byType(FieldReconciliationDialog), findsNothing);
  });

  testWidgets('con varios campos muestra "1 de N" y avanza al resolver uno', (
    tester,
  ) async {
    await mapThreeFields();
    // Desaparecen "cédula" y "correo".
    await replaceColumns(<String>['nombre', 'id', 'otra']);
    await openDialog(tester);

    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.textContaining('«cédula»'), findsOneWidget);

    await tester.tap(find.text('Se eliminó'));
    await tester.pumpAndSettle();

    expect(find.textContaining('«correo»'), findsOneWidget);
    expect(find.text('1 de 2'), findsNothing);
    expect(container.read(fieldReconciliationProvider), hasLength(1));
  });

  testWidgets('"Se eliminó" quita el campo y se puede deshacer', (
    tester,
  ) async {
    await mapThreeFields();
    await replaceColumns(<String>['nombre', 'correo']);
    await openDialog(tester);

    await tester.tap(find.text('Se eliminó'));
    await tester.pumpAndSettle();

    expect(
      container
          .read(activeMappingProvider)
          .state
          .assignments
          .map((a) => a.fieldHeader),
      <String>['nombre', 'correo'],
    );
    expect(find.byType(FieldReconciliationDialog), findsNothing);

    container.read(activeMappingProvider.notifier).undo();
    expect(container.read(fieldReconciliationProvider), hasLength(1));
  });

  testWidgets('"Resolver después" cierra y anota el campo como visto', (
    tester,
  ) async {
    await mapThreeFields();
    await replaceColumns(<String>['nombre', 'correo']);
    await openDialog(tester);

    await tester.tap(find.text('Resolver después'));
    await tester.pumpAndSettle();

    expect(find.byType(FieldReconciliationDialog), findsNothing);
    expect(container.read(dismissedOrphanHeadersProvider), <String>{'cédula'});
    // Sigue pendiente: no se resolvió nada.
    expect(container.read(fieldReconciliationProvider), hasLength(1));
  });
}
