import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';
import 'package:forkumentos/shared/widgets/mapping_aware_paragraph.dart';

void main() {
  testWidgets('dibuja la imagen incrustada en la posición del run', (
    WidgetTester tester,
  ) async {
    await _pumpParagraph(
      tester,
      DocumentParagraph(
        runs: <DocumentRun>[
          _run('Antes'),
          _run('', image: _image(width: 60, height: 24)),
          _run('Después'),
        ],
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 60);
    expect(image.height, 24);
    // La imagen queda ENTRE los dos runs de texto: en el flujo del pintor
    // ocupa el carácter de reemplazo U+FFFC.
    expect(
      tester.widget<RichText>(find.byType(RichText)).text.toPlainText(),
      'Antes￼Después',
    );
  });

  testWidgets('un párrafo que solo contiene una imagen sigue dibujándola', (
    WidgetTester tester,
  ) async {
    await _pumpParagraph(
      tester,
      DocumentParagraph(
        runs: <DocumentRun>[_run('', image: _image(width: 40, height: 40))],
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('la selección reporta offsets del documento, no del pintor', (
    WidgetTester tester,
  ) async {
    DocumentTextSelection? captured;
    await _pumpParagraph(
      tester,
      DocumentParagraph(
        runs: <DocumentRun>[
          // La imagen va primero: en el espacio del pintor ocupa un carácter
          // que desplazaría todos los offsets del texto si no se descontara.
          _run('', image: _image(width: 20, height: 12)),
          _run('Confidencial'),
        ],
      ),
      onSelectionChanged: (selection) => captured = selection,
    );

    // Mantener pulsado sobre la palabra la selecciona entera; con la imagen
    // delante, el pintor la ubica en 1..13 y el documento en 0..12.
    final textRect = tester.getRect(find.byType(SelectableText));
    await tester.longPressAt(Offset(textRect.left + 30, textRect.center.dy));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.selectedText, 'Confidencial');
    expect(captured!.startOffset, 0);
    expect(captured!.endOffset, 12);
  });

  testWidgets('la alineación y las sangrías del párrafo llegan al texto', (
    WidgetTester tester,
  ) async {
    await _pumpParagraph(
      tester,
      DocumentParagraph(
        runs: <DocumentRun>[_run('Centrado')],
        alignment: DocumentAlignment.center,
        indentLeftPoints: 24,
        indentRightPoints: 12,
        spacingBeforePoints: 6,
        spacingAfterPoints: 8,
      ),
    );

    expect(
      tester.widget<RichText>(find.byType(RichText)).textAlign,
      TextAlign.center,
    );
    final padding = tester.widget<Padding>(
      find
          .ancestor(of: find.byType(RichText), matching: find.byType(Padding))
          .first,
    );
    expect(
      padding.padding,
      const EdgeInsets.only(top: 6, bottom: 8, left: 24, right: 12),
    );
  });

  testWidgets('un párrafo vacío conserva el espaciado de Word', (
    WidgetTester tester,
  ) async {
    await _pumpParagraph(
      tester,
      const DocumentParagraph(
        runs: <DocumentRun>[],
        spacingBeforePoints: 10,
        spacingAfterPoints: 4,
      ),
    );

    final padding = tester.widget<Padding>(
      find
          .ancestor(of: find.byType(SizedBox), matching: find.byType(Padding))
          .first,
    );
    expect(padding.padding, const EdgeInsets.only(top: 10, bottom: 4));
  });

  group('escala visual', () {
    testWidgets('el texto se pinta al tamaño nominal escalado', (
      WidgetTester tester,
    ) async {
      await _pumpParagraph(
        tester,
        DocumentParagraph(runs: <DocumentRun>[_run('Cuerpo', fontSize: 11)]),
      );

      expect(_renderedFontSize(tester), closeTo(11 * _expectedScale, 1e-9));
    });

    testWidgets('el modelo de datos no se toca al renderizar', (
      WidgetTester tester,
    ) async {
      final paragraph = DocumentParagraph(
        runs: <DocumentRun>[_run('Cuerpo', fontSize: 11)],
      );

      await _pumpParagraph(tester, paragraph);

      // La exportación a DOCX y PDF lee el modelo, no el widget: si la escala
      // se filtrara al modelo saldría todo un 5% más pequeño en los
      // documentos finales.
      expect(paragraph.runs.first.fontSizePoints, 11);
      expect(_renderedFontSize(tester), isNot(11));
    });

    testWidgets('el interlineado exacto del DOCX sobrevive a la escala', (
      WidgetTester tester,
    ) async {
      await _pumpParagraph(
        tester,
        DocumentParagraph(
          runs: <DocumentRun>[_run('Cuerpo', fontSize: 11)],
          lineSpacingExactPoints: 18,
        ),
      );

      // `w:line` exacto es una medida absoluta en puntos: Flutter resuelve el
      // alto de línea como `height * fontSize`, así que el factor tiene que
      // estar calculado sobre el tamaño YA escalado para volver a dar 18pt.
      final style = _renderedRunStyle(tester);
      expect(style.fontSize! * style.height!, closeTo(18, 1e-9));
      expect(tester.getSize(find.byType(RichText)).height, closeTo(18, 1e-9));
    });

    testWidgets('el interlineado natural sí escala con la fuente', (
      WidgetTester tester,
    ) async {
      await _pumpParagraph(
        tester,
        DocumentParagraph(runs: <DocumentRun>[_run('Cuerpo', fontSize: 11)]),
      );

      // Sin `w:line` explícito el alto lo pone la métrica de la fuente sobre
      // el tamaño escalado, que es justo lo que sobra respecto al
      // presupuesto del paginador. Dejar `height` en null es lo que cede ese
      // control a la fuente.
      final style = _renderedRunStyle(tester);
      expect(style.height, isNull);
      expect(
        tester.getSize(find.byType(RichText)).height,
        // La fuente sintética de flutter_test redondea el alto de línea al
        // punto entero, de ahí la tolerancia.
        closeTo(style.fontSize! * _testFontLineHeightRatio, 0.5),
      );
    });

    testWidgets('la escala cabe bajo el techo de la fuente de peor caso', (
      WidgetTester tester,
    ) async {
      await _pumpParagraph(
        tester,
        DocumentParagraph(runs: <DocumentRun>[_run('Cuerpo', fontSize: 11)]),
      );
      final scale = _renderedFontSize(tester) / 11;

      // El paginador presupuesta cada línea a `fontSize * 1.17`; el visor la
      // pinta a `fontSize * ratio_real`. Para que una página que el parser dio
      // por llena quepa, el alto pintado no puede superar el presupuestado.
      expect(
        scale * _worstCaseLineHeightRatio,
        lessThanOrEqualTo(_parserAssumedLineHeightRatio),
      );
      // Y la compensación es un ajuste fino, no un encogimiento: pasado este
      // suelo dejaría de ser fiel al tamaño que declara el documento.
      expect(scale, greaterThan(0.9));
    });

    testWidgets('una página llena de cuerpo no desborda la banda', (
      WidgetTester tester,
    ) async {
      // Carta con márgenes de una pulgada, que es lo que trae un contrato
      // normal: 792 - 72 - 72 puntos de área de contenido, todo medido a
      // escala x10 (ver `_geometryScale`).
      const contentHeightPoints = (792.0 - 72 - 72) * _geometryScale;
      const contentWidthPoints = (612.0 - 72 - 72) * _geometryScale;
      const bodyFontSizePoints = 11.0 * _geometryScale;
      // Líneas que el paginador mete en esa banda con su presupuesto de 1.17.
      final lineCount =
          contentHeightPoints ~/
          (bodyFontSizePoints * _parserAssumedLineHeightRatio);
      // La fuente sintética de flutter_test mide 1.0 para cualquier familia,
      // así que una hoja a tamaño real no probaría nada. Encoger la banda por
      // el ratio de Calibri reproduce, con métricas deterministas, la misma
      // geometría que tiene esa página con la fuente real instalada.
      const bandHeightPoints =
          contentHeightPoints / _worstCaseLineHeightRatio;

      // La superficie de prueba por defecto (800x600) recortaría la hoja y el
      // texto se partiría en líneas de más, midiendo cualquier cosa menos lo
      // que se quiere medir.
      await tester.binding.setSurfaceSize(
        const Size(contentWidthPoints + 200, contentHeightPoints + 200),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final page = <Widget>[
        for (var index = 0; index < lineCount; index++)
          MappingAwareParagraph(
            path: _pathAt(index),
            paragraph: DocumentParagraph(
              runs: <DocumentRun>[
                // Corto de sobra para no partirse en dos líneas ni siquiera
                // al tamaño nominal: así la prueba mide alto, no ancho.
                _run(
                  'Cláusula primera del contrato de obra.',
                  fontSize: bodyFontSizePoints,
                ),
              ],
            ),
            textStyle: _bodyStyle,
            highlights: const <ParagraphHighlightSegment>[],
          ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: contentWidthPoints,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: page,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(Column).last).height,
        lessThanOrEqualTo(bandHeightPoints),
      );

      // Y la misma página dentro de una banda de alto fijo, que es como la
      // dibuja el visor, no desborda.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: contentWidthPoints,
              height: bandHeightPoints,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: page,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}

// Alto natural de línea que asume el paginador de
// `docx_document_repository.dart` para presupuestar cuánto cabe por página.
const _parserAssumedLineHeightRatio = 1.17;

// Alto natural de línea REAL de Calibri, la fuente de cuerpo por defecto de
// Word y la peor de las habituales en Windows: 2500/2048 medido con GDI+
// `FontFamily.GetLineSpacing / GetEmHeight`. Cambria da 1,1724 y
// Times New Roman y Arial 1,1499, todas por debajo del presupuesto.
const _worstCaseLineHeightRatio = 2500 / 2048;

// flutter_test sustituye cualquier familia por su fuente sintética, cuyo alto
// de línea es exactamente el tamaño de fuente.
const _testFontLineHeightRatio = 1.0;

// Esa misma fuente redondea el alto de línea al punto entero, así que a 11pt
// un escalado de 0,95 se mediría como 10 en vez de 10,45 y la prueba de
// página saldría un 4% optimista. Medir la hoja entera a escala x10 deja el
// sesgo del redondeo por debajo del 0,5% sin cambiar ninguna proporción.
const _geometryScale = 10.0;

// El valor de `_visualScale` en el widget. Se repite aquí a propósito: es la
// prueba la que fija el número, así que tocar la constante rompe el test.
const _expectedScale = 0.95;

const _bodyStyle = TextStyle(fontSize: 11, color: Colors.black);

DocumentTextPath _pathAt(int blockIndex) {
  return DocumentTextPath(
    pageIndex: 0,
    steps: <DocumentPathStep>[
      DocumentPathStep.rootBlock(blockIndex: blockIndex),
    ],
  );
}

TextStyle _renderedRunStyle(WidgetTester tester) {
  final root = tester.widget<RichText>(find.byType(RichText)).text as TextSpan;
  return (root.children!.first as TextSpan).style!;
}

double _renderedFontSize(WidgetTester tester) =>
    _renderedRunStyle(tester).fontSize!;

Future<void> _pumpParagraph(
  WidgetTester tester,
  DocumentParagraph paragraph, {
  ValueChanged<DocumentTextSelection?>? onSelectionChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: MappingAwareParagraph(
              path: _pathAt(0),
              paragraph: paragraph,
              textStyle: _bodyStyle,
              highlights: const <ParagraphHighlightSegment>[],
              onSelectionChanged: onSelectionChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

DocumentRun _run(String text, {DocumentImage? image, double? fontSize}) {
  return DocumentRun(
    text: text,
    isBold: false,
    isItalic: false,
    isUnderlined: false,
    image: image,
    fontSizePoints: fontSize,
  );
}

DocumentImage _image({required double width, required double height}) {
  return DocumentImage(
    bytes: Uint8List.fromList(_pngBytes),
    widthPoints: width,
    heightPoints: height,
  );
}

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
