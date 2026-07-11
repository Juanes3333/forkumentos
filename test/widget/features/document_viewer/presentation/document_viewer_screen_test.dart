import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/document_viewer/data/document_repository_provider.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_controller.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_screen.dart';
import 'package:forkumentos/shared/models/document.dart';

import '../../../../support/fakes.dart';

void main() {
  testWidgets('muestra estado vacío cuando documentPath es null', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(),
      documentPath: null,
      isSourceLoading: false,
      sourceErrorMessage: null,
    );

    expect(
      find.text('Todavía no importaste una plantilla DOCX para este proyecto.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra estado de carga de origen', (WidgetTester tester) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: true,
      sourceErrorMessage: null,
    );

    expect(find.text('Cargando documento...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('muestra error de origen cuando sourceErrorMessage existe', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: 'No hay plantilla activa.',
    );

    expect(
      find.text('No se pudo preparar la vista del documento.'),
      findsOneWidget,
    );
    expect(find.text('No hay plantilla activa.'), findsOneWidget);
  });

  testWidgets('render exitoso muestra texto y página actual', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[
            _buildPage(number: 1, text: 'Página uno'),
            _buildPage(number: 2, text: 'Página dos'),
          ],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
    );
    await tester.pumpAndSettle();

    expect(find.text('Página uno', findRichText: true), findsOneWidget);
    expect(find.text('Página 1 de 2'), findsOneWidget);
  });

  testWidgets('zoom in/out actualiza porcentaje vía controller', (
    WidgetTester tester,
  ) async {
    final controller = DocumentViewerController();
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[_buildPage(number: 1, text: 'Zoom')],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
      controller: controller,
    );
    await tester.pumpAndSettle();

    expect(controller.zoomPercentage, 100);

    controller.zoomIn();
    await tester.pumpAndSettle();
    expect(controller.zoomPercentage, 125);

    controller.zoomOut();
    await tester.pumpAndSettle();
    expect(controller.zoomPercentage, 100);

    controller.setScale(1.5);
    await tester.pumpAndSettle();
    expect(controller.zoomPercentage, 150);

    controller.dispose();
  });

  testWidgets('fit width y fit page actualizan estado vía controller', (
    WidgetTester tester,
  ) async {
    final controller = DocumentViewerController();
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[_buildPage(number: 1, text: 'Fit')],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
      controller: controller,
    );
    await tester.pumpAndSettle();

    expect(controller.isFitWidth, isFalse);
    expect(controller.isFitPage, isFalse);

    controller.fitWidth();
    await tester.pumpAndSettle();
    expect(controller.isFitWidth, isTrue);
    expect(controller.isFitPage, isFalse);

    controller.fitPage();
    await tester.pumpAndSettle();
    expect(controller.isFitWidth, isFalse);
    expect(controller.isFitPage, isTrue);

    controller.dispose();
  });

  testWidgets('toolbar del viewer solo muestra navegación de páginas', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[_buildPage(number: 1, text: 'Nav')],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
    );
    await tester.pumpAndSettle();

    expect(find.text('Página 1 de 1'), findsOneWidget);
    expect(find.byTooltip('Acercar'), findsNothing);
    expect(find.byTooltip('Alejar'), findsNothing);
    expect(find.text('Ajustar ancho'), findsNothing);
    expect(find.text('Ajustar página'), findsNothing);
  });

  testWidgets('navegación prev/next se habilita según límites', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[
            _buildPage(number: 1, text: 'Primera'),
            _buildPage(number: 2, text: 'Segunda'),
          ],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
    );
    await tester.pumpAndSettle();

    var previousButton = tester.widget<IconButton>(
      _iconButtonByIcon(Icons.navigate_before),
    );
    var nextButton = tester.widget<IconButton>(
      _iconButtonByIcon(Icons.navigate_next),
    );
    expect(previousButton.onPressed, isNull);
    expect(nextButton.onPressed, isNotNull);

    nextButton.onPressed!.call();
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 2'), findsOneWidget);

    previousButton = tester.widget<IconButton>(
      _iconButtonByIcon(Icons.navigate_before),
    );
    nextButton = tester.widget<IconButton>(
      _iconButtonByIcon(Icons.navigate_next),
    );
    expect(previousButton.onPressed, isNotNull);
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('muestra banner de omisiones cuando existen', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[_buildPage(number: 1, text: 'Con omisiones')],
          omissions: const <DocumentOmission>{
            DocumentOmission.image,
            DocumentOmission.headerFooter,
          },
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no se muestran en esta vista previa'),
      findsOneWidget,
    );
  });

  testWidgets('no muestra banner de omisiones cuando no hay omisiones', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[_buildPage(number: 1, text: 'Sin omisiones')],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no se muestran en esta vista previa'),
      findsNothing,
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FakeDocumentRepository repository,
  required String? documentPath,
  required bool isSourceLoading,
  required String? sourceErrorMessage,
  DocumentViewerController? controller,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        documentRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DocumentViewerScreen(
            documentPath: documentPath,
            isSourceLoading: isSourceLoading,
            sourceErrorMessage: sourceErrorMessage,
            controller: controller,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _iconButtonByIcon(IconData icon) {
  return find.ancestor(
    of: find.byIcon(icon),
    matching: find.byType(IconButton),
  );
}

Document _buildDocument({
  required List<DocumentPage> pages,
  Set<DocumentOmission> omissions = const <DocumentOmission>{},
}) {
  return Document(pages: pages, omissions: omissions);
}

DocumentPage _buildPage({required int number, required String text}) {
  return DocumentPage(
    number: number,
    widthPoints: 612,
    heightPoints: 792,
    margins: const DocumentMargins(
      topPoints: 72,
      rightPoints: 72,
      bottomPoints: 72,
      leftPoints: 72,
    ),
    blocks: <DocumentBlock>[
      DocumentBlock.paragraph(
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
      ),
    ],
  );
}
