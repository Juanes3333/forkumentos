import 'dart:typed_data';

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

  testWidgets('encabezado y pie se anclan dentro de los márgenes como en '
      'Word', (WidgetTester tester) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[_buildPage(number: 1, text: 'Cuerpo')],
          header: <DocumentBlock>[_textBlock('Encabezado')],
          footer: <DocumentBlock>[_textBlock('Pie')],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
    );
    await tester.pumpAndSettle();

    final pageRect = tester.getRect(_pageSheetFinder);
    // Al 100% un punto de documento es un píxel lógico: la hoja mide
    // exactamente lo que declara el DOCX.
    expect(pageRect.width, closeTo(612, 0.5));
    expect(pageRect.height, closeTo(792, 0.5));

    final headerRect = tester.getRect(
      find.text('Encabezado', findRichText: true),
    );
    final bodyRect = tester.getRect(find.text('Cuerpo', findRichText: true));
    final footerRect = tester.getRect(find.text('Pie', findRichText: true));

    // El encabezado vive DENTRO del margen superior, a w:pgMar/@header del
    // borde; el cuerpo arranca en el margen; el pie se apoya a
    // w:pgMar/@footer del borde inferior.
    expect(headerRect.top - pageRect.top, closeTo(36, 0.5));
    expect(bodyRect.top - pageRect.top, closeTo(72, 0.5));
    expect(pageRect.bottom - footerRect.bottom, closeTo(36, 0.5));
  });

  testWidgets('dibuja las imágenes del cuerpo y del encabezado', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[
            _buildPage(number: 1, text: 'Cuerpo', imageWidthPoints: 120),
          ],
          header: <DocumentBlock>[_imageBlock(widthPoints: 80)],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
    );
    await tester.pumpAndSettle();

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images.map((image) => image.width), containsAll(<double>[80, 120]));
  });

  testWidgets('una tabla sin bordes declarados no dibuja retícula', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[_buildTablePage(borderWidthPoints: 0)],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Table>(find.byType(Table)).border, isNull);
    // La retícula del DOCX manda sobre el ancho disponible.
    expect(tester.getSize(find.byType(Table)).width, closeTo(300, 0.5));
  });

  testWidgets('una tabla con w:tblBorders sí dibuja retícula', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[_buildTablePage(borderWidthPoints: 1.5)],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Table>(find.byType(Table)).border?.top.width, 1.5);
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

  testWidgets('incrementar focusToken hace scroll hasta una página posterior', (
    WidgetTester tester,
  ) async {
    final pages = List<DocumentPage>.generate(
      5,
      (i) => _buildPage(number: i + 1, text: 'Página ${i + 1}'),
    );
    final repository = FakeDocumentRepository(
      loadHandler: (_) async => _buildDocument(pages: pages),
    );

    var focusPageIndex = 0;
    var focusToken = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          documentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setLocalState) {
                return Column(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => setLocalState(() {
                        focusPageIndex = 3;
                        focusToken++;
                      }),
                      child: const Text('ir a página 4'),
                    ),
                    SizedBox(
                      height: 400,
                      width: 800,
                      child: DocumentViewerScreen(
                        documentPath: '/tmp/documento.docx',
                        isSourceLoading: false,
                        focusPageIndex: focusPageIndex,
                        focusToken: focusToken,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final beforeTop = tester
        .getTopLeft(find.text('Página 4', findRichText: true))
        .dy;
    expect(
      beforeTop,
      greaterThanOrEqualTo(400),
      reason: 'página 4 debe iniciar fuera del viewport de 400px',
    );

    await tester.tap(find.text('ir a página 4'));
    await tester.pumpAndSettle();

    final afterTop = tester
        .getTopLeft(find.text('Página 4', findRichText: true))
        .dy;
    expect(
      afterTop,
      inInclusiveRange(0, 400),
      reason:
          'página 4 debe quedar visible dentro del viewport tras '
          'el autoscroll',
    );
  });

  testWidgets('muestra header y footer en cada página cuando existen', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[
            _buildPage(number: 1, text: 'Cuerpo página uno'),
            _buildPage(number: 2, text: 'Cuerpo página dos'),
          ],
          header: <DocumentBlock>[_textBlock('Encabezado del documento')],
          footer: <DocumentBlock>[_textBlock('Pie del documento')],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Encabezado del documento', findRichText: true),
      findsNWidgets(2),
      reason: 'el header debe repetirse en cada una de las 2 páginas',
    );
    expect(
      find.text('Pie del documento', findRichText: true),
      findsNWidgets(2),
      reason: 'el footer debe repetirse en cada una de las 2 páginas',
    );
  });

  testWidgets('no agrega espacio ni divisores cuando no hay header/footer', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeDocumentRepository(
        loadHandler: (_) async => _buildDocument(
          pages: <DocumentPage>[_buildPage(number: 1, text: 'Sin encabezado')],
        ),
      ),
      documentPath: '/tmp/documento.docx',
      isSourceLoading: false,
      sourceErrorMessage: null,
    );
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsNothing);
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
  List<DocumentBlock> header = const <DocumentBlock>[],
  List<DocumentBlock> footer = const <DocumentBlock>[],
}) {
  return Document(
    pages: pages,
    omissions: omissions,
    header: header,
    footer: footer,
  );
}

DocumentBlock _textBlock(String text) {
  return DocumentBlock.paragraph(
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
}

DocumentBlock _imageBlock({required double widthPoints}) {
  return DocumentBlock.paragraph(
    DocumentParagraph(
      runs: <DocumentRun>[
        DocumentRun(
          text: '',
          isBold: false,
          isItalic: false,
          isUnderlined: false,
          image: DocumentImage(
            bytes: Uint8List.fromList(_pngBytes),
            widthPoints: widthPoints,
            heightPoints: widthPoints / 2,
          ),
        ),
      ],
    ),
  );
}

DocumentPage _buildPage({
  required int number,
  required String text,
  double? imageWidthPoints,
}) {
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
      if (imageWidthPoints != null) _imageBlock(widthPoints: imageWidthPoints),
    ],
  );
}

DocumentPage _buildTablePage({required double borderWidthPoints}) {
  return DocumentPage(
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
      DocumentBlock.table(
        DocumentTable(
          rows: <DocumentTableRow>[
            DocumentTableRow(
              cells: <DocumentTableCell>[
                DocumentTableCell(blocks: <DocumentBlock>[_textBlock('Campo')]),
                DocumentTableCell(blocks: <DocumentBlock>[_textBlock('Valor')]),
              ],
            ),
          ],
          columnWidthsPoints: const <double>[180, 120],
          borderWidthPoints: borderWidthPoints,
        ),
      ),
    ],
  );
}

/// La caja en PUNTOS que envuelve el contenido de la hoja: al 100% de zoom
/// coincide con el tamaño de página declarado por el DOCX.
final Finder _pageSheetFinder = find.byWidgetPredicate(
  (Widget widget) =>
      widget is SizedBox && widget.width == 612 && widget.height == null,
);

const _pngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99,
  0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
