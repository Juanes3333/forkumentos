import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/app/app.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/template/data/template_repository_provider.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/app_phase_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_selection_provider.dart';
import 'package:forkumentos/shared/data/document_repository_provider.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

import '../../../support/fakes.dart';

void main() {
  group('con Excel', () {
    testWidgets('el cuadro de asignar no tapa el texto seleccionado en una '
        'celda de tabla', (WidgetTester tester) async {
      final container = await _loadWorkbench(tester, withDatasource: true);

      final cell = await _dragSelectCell(tester, 'MARIA STELLA');

      // Con la celda lo bastante abajo para que "arriba" quepa en el cálculo
      // aproximado, el cuadro real (más alto de lo supuesto) la cubría.
      expect(tester.getRect(cell).top, greaterThan(250));
      expect(find.text('Asignar campo'), findsOneWidget);
      final bounds = container.read(workbenchSelectionProvider).bounds;
      expect(bounds, isNotNull);
      final tooltip = _tooltipRect(tester);
      expect(
        tooltip.overlaps(bounds!),
        isFalse,
        reason: 'cuadro $tooltip sobre la selección $bounds',
      );
      final window = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tooltip.top, greaterThanOrEqualTo(0));
      expect(tooltip.bottom, lessThanOrEqualTo(window.height));
    });

    testWidgets('asignar desde una celda crea la asignación en esa celda', (
      WidgetTester tester,
    ) async {
      final container = await _loadWorkbench(tester, withDatasource: true);

      await _dragSelectCell(tester, 'MARIA STELLA');
      await tester.tap(find.widgetWithText(FilledButton, 'Asignar'));
      await tester.pumpAndSettle();

      final assignments = container
          .read(activeMappingProvider)
          .state
          .assignments;
      expect(assignments, hasLength(1));
      expect(assignments.single.selectedText, 'MARIA STELLA');
      expect(
        assignments.single.path.steps.last,
        isA<DocumentTableCellBlockStep>(),
      );
    });
  });

  group('sin Excel (proyecto solo con el Word)', () {
    testWidgets('se puede seleccionar el texto de una celda y crear el campo '
        'desde ahí', (WidgetTester tester) async {
      final container = await _loadWorkbench(tester, withDatasource: false);

      await _dragSelectCell(tester, 'MARIA STELLA');

      expect(find.text('Asignar campo'), findsOneWidget);
      final bounds = container.read(workbenchSelectionProvider).bounds;
      expect(_tooltipRect(tester).overlaps(bounds!), isFalse);
      expect(
        find.widgetWithText(FilledButton, 'Asignar').evaluate().single.widget,
        isA<FilledButton>().having(
          (button) => button.onPressed,
          'onPressed',
          isNull,
        ),
        reason: 'sin campos todavía solo se ofrece crear uno',
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Crear campo nuevo'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'contratista');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear campo'));
      await tester.pumpAndSettle();

      expect(
        container.read(activeProjectProvider).valueOrNull?.draftFields,
        <String>['contratista'],
      );
      final assignments = container
          .read(activeMappingProvider)
          .state
          .assignments;
      expect(assignments, hasLength(1));
      expect(assignments.single.fieldHeader, 'contratista');
      expect(assignments.single.selectedText, 'MARIA STELLA');
      expect(
        assignments.single.path.steps.last,
        isA<DocumentTableCellBlockStep>(),
      );
    });

    testWidgets('un párrafo normal también se puede seleccionar', (
      WidgetTester tester,
    ) async {
      await _loadWorkbench(tester, withDatasource: false);

      await _dragSelect(tester, find.text('Cláusula primera del contrato.'));

      expect(find.text('Asignar campo'), findsOneWidget);
    });
  });
}

/// Carga el banco de trabajo con una hoja: 14 párrafos, y debajo una tabla
/// de dos columnas (así la celda queda a media altura de la ventana).
Future<ProviderContainer> _loadWorkbench(
  WidgetTester tester, {
  required bool withDatasource,
}) async {
  await tester.binding.setSurfaceSize(const Size(1366, 768));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(
    overrides: <Override>[
      loggingServiceProvider.overrideWithValue(FakeLoggingService()),
      projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
      datasourceRepositoryProvider.overrideWithValue(
        FakeDatasourceRepository(),
      ),
      templateRepositoryProvider.overrideWithValue(FakeTemplateRepository()),
      documentRepositoryProvider.overrideWithValue(
        FakeDocumentRepository(loadHandler: (_) async => _documentWithTable()),
      ),
      windowServiceProvider.overrideWithValue(FakeWindowService()),
    ],
  );
  addTearDown(container.dispose);

  await container
      .read(activeProjectProvider.notifier)
      .createProject(name: 'Proyecto');
  await container
      .read(activeTemplateProvider.notifier)
      .importTemplate(filePath: '/tmp/plantilla.docx');
  if (withDatasource) {
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: '/tmp/clientes.csv');
  }
  container.read(workbenchEnteredProvider.notifier).enterWorkbench();

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Arrastra el ratón sobre todo el texto de la celda cuyo contenido es
/// [text] y devuelve el buscador de ese texto.
Future<Finder> _dragSelectCell(WidgetTester tester, String text) async {
  final cell = find.byWidgetPredicate(
    (widget) =>
        widget is SelectableText &&
        (widget.textSpan?.toPlainText() ?? '') == text,
  );
  expect(
    cell,
    findsOneWidget,
    reason: 'la celda "$text" debe ser seleccionable',
  );
  await _dragSelect(tester, cell);
  return cell;
}

Future<void> _dragSelect(WidgetTester tester, Finder target) async {
  final rect = tester.getRect(target);
  final gesture = await tester.startGesture(
    Offset(rect.left + 2, rect.center.dy),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(Offset(rect.right - 2, rect.center.dy));
  await gesture.up();
  await tester.pumpAndSettle();
}

Rect _tooltipRect(WidgetTester tester) {
  return tester.getRect(
    find
        .ancestor(
          of: find.text('Asignar campo'),
          matching: find.byType(Material),
        )
        .first,
  );
}

Document _documentWithTable() {
  DocumentBlock paragraph(String text) => DocumentBlock.paragraph(
    DocumentParagraph(
      runs: <DocumentRun>[
        DocumentRun(
          text: text,
          isBold: false,
          isItalic: false,
          isUnderlined: false,
        ),
      ],
    ),
  );

  return Document(
    pages: <DocumentPage>[
      DocumentPage(
        number: 1,
        widthPoints: 612,
        heightPoints: 792,
        margins: const DocumentMargins(
          topPoints: 72,
          rightPoints: 72,
          bottomPoints: 72,
          leftPoints: 72,
        ),
        blocks: <DocumentBlock>[
          paragraph('Cláusula primera del contrato.'),
          for (var index = 0; index < 13; index++)
            paragraph('Texto de relleno número $index.'),
          DocumentBlock.table(
            DocumentTable(
              rows: <DocumentTableRow>[
                DocumentTableRow(
                  cells: <DocumentTableCell>[
                    DocumentTableCell(
                      blocks: <DocumentBlock>[paragraph('CONTRATISTA')],
                    ),
                    DocumentTableCell(
                      blocks: <DocumentBlock>[paragraph('MARIA STELLA')],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ],
    omissions: const <DocumentOmission>{},
  );
}

final class _FakeProjectRepository implements ProjectRepository {
  @override
  Future<Project> load(
    String filePath, {
    required String cacheDirectory,
  }) async {
    return Project(
      id: 'default-loaded-id',
      name: 'Proyecto Cargado',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      filePath: filePath,
    );
  }

  @override
  Future<Project> save({
    required Project project,
    required String filePath,
    String? templateSourcePath,
    String? datasourceSourcePath,
    String? cacheDirectory,
  }) async {
    return project.copyWith(
      filePath: filePath,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
