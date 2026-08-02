import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/export/data/pdf_export_command.dart';
import 'package:forkumentos/features/export/domain/export_result.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_pdf_export_test_',
    );
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('tabla con filas parejas se exporta sin excepción', () async {
    final document = _pageDocument(
      blocks: <DocumentBlock>[
        _table(<List<String>>[
          <String>['A1', 'B1'],
          <String>['A2', 'B2'],
        ]),
      ],
    );

    final result = await _export(tempDirectory.path, document);

    expect(result.failedCount, 0);
    expect(result.exportedCount, 1);
    expect(result.errors, isEmpty);
  });

  test(
    'tabla con filas desiguales (celda fusionada simulada) no lanza excepción',
    () async {
      final document = _pageDocument(
        blocks: <DocumentBlock>[
          _table(<List<String>>[
            <String>['A1', 'B1', 'C1'],
            <String>['A2'], // fewer cells: simulates a merged cell upstream
          ]),
        ],
      );

      final result = await _export(tempDirectory.path, document);

      expect(
        result.errors,
        isEmpty,
        reason: 'filas de tabla desiguales no deberían fallar el render',
      );
      expect(result.failedCount, 0);
      expect(result.exportedCount, 1);
    },
  );

  test('header y footer del documento aparecen en el PDF', () async {
    final document = Document(
      pages: <DocumentPage>[
        _page(blocks: <DocumentBlock>[_paragraph('Cuerpo del documento')]),
      ],
      omissions: const <DocumentOmission>{},
      header: <DocumentBlock>[_paragraph('Encabezado de prueba')],
      footer: <DocumentBlock>[_paragraph('Pie de página de prueba')],
    );

    final result = await _export(tempDirectory.path, document);
    expect(result.failedCount, 0);

    final text = _extractAllText(File(result.writtenFiles.single));
    expect(text, contains('Encabezado de prueba'));
    expect(text, contains('Pie de página de prueba'));
    expect(text, contains('Cuerpo del documento'));
  });

  test('una página cuyo contenido excede el alto nominal sigue siendo UNA '
      'sola hoja y no lanza excepción', () async {
    final document = _pageDocument(
      widthPoints: 200,
      heightPoints: 100,
      blocks: <DocumentBlock>[
        for (var i = 0; i < 25; i++) _paragraph('Línea de contenido $i'),
      ],
    );

    final result = await _export(tempDirectory.path, document);

    expect(result.failedCount, 0);
    expect(result.errors, isEmpty);

    final bytes = File(result.writtenFiles.single).readAsBytesSync();
    expect(bytes, isNotEmpty);

    final pdf = PdfDocument(inputBytes: bytes);
    try {
      // Paginación estricta: un DocumentPage es UNA hoja pase lo que pase.
      // Dejar que el desbordamiento invente una hoja de continuación
      // desalinearía el PDF del visor y de Word a partir de ahí.
      expect(
        pdf.pages.count,
        1,
        reason: 'un DocumentPage nunca puede producir dos hojas',
      );
    } finally {
      pdf.dispose();
    }
  });

  test(
    'cada DocumentPage produce exactamente una hoja de PDF, en orden',
    () async {
      final document = Document(
        pages: <DocumentPage>[
          _page(blocks: <DocumentBlock>[_paragraph('Pagina A')]),
          _page(blocks: <DocumentBlock>[_paragraph('Pagina B')]),
          _page(blocks: <DocumentBlock>[_paragraph('Pagina C')]),
        ],
        omissions: const <DocumentOmission>{},
      );

      final result = await _export(tempDirectory.path, document);
      expect(result.failedCount, 0);

      final bytes = File(result.writtenFiles.single).readAsBytesSync();
      final pdf = PdfDocument(inputBytes: bytes);
      try {
        expect(pdf.pages.count, 3);
        // Y en el mismo orden: cada hoja lleva SOLO el bloque de su página.
        for (final entry in <int, String>{0: 'A', 1: 'B', 2: 'C'}.entries) {
          final sheetText = PdfTextExtractor(pdf)
              .extractText(startPageIndex: entry.key, endPageIndex: entry.key)
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          expect(sheetText, contains('Pagina ${entry.value}'));
        }
      } finally {
        pdf.dispose();
      }
    },
  );

  test(
    'una página llena de cuerpo al presupuesto del parser no se recorta',
    () async {
      // El paginador de docx_document_repository.dart presupuesta una página
      // como (alto útil / (fontSize * 1.17)) líneas de (ancho útil /
      // (fontSize * 0.44)) caracteres. Para carta con márgenes de 20pt a 11pt
      // eso son ~59 líneas de ~118 caracteres. Si el PDF dibujara ese mismo
      // volumen más alto que la hoja, `pw.Page` lo recortaría EN SILENCIO y se
      // perdería texto exportado — el peor fallo posible de este módulo.
      const lines = 59;
      final document = _pageDocument(
        blocks: <DocumentBlock>[
          for (var i = 0; i < lines; i++) _paragraph('${'palabra ' * 14}fin$i'),
        ],
      );

      final result = await _export(tempDirectory.path, document);
      expect(result.failedCount, 0);
      expect(result.errors, isEmpty);

      final text = _extractAllText(File(result.writtenFiles.single));
      // El marcador del ÚLTIMO párrafo debe haber sobrevivido: si falta, el
      // contenido desbordó el alto de la hoja y `pw.Page` lo recortó en
      // silencio, que es exactamente lo que el FittedBox existe para impedir.
      expect(
        text,
        contains('fin${lines - 1}'),
        reason: 'se perdió el final de la página: el contenido se recortó',
      );
    },
  );

  test('pageIndexes nulo o vacío exporta todas las páginas', () async {
    final document = Document(
      pages: <DocumentPage>[
        _page(blocks: <DocumentBlock>[_paragraph('Pagina A')]),
        _page(blocks: <DocumentBlock>[_paragraph('Pagina B')]),
        _page(blocks: <DocumentBlock>[_paragraph('Pagina C')]),
      ],
      omissions: const <DocumentOmission>{},
    );

    final result = await _export(tempDirectory.path, document);
    expect(result.failedCount, 0);

    // El conteo 1:1 lo cubre el test de paginación estricta; aquí solo
    // interesa que no se pierda ninguna página por el camino.
    final text = _extractAllText(File(result.writtenFiles.single));
    expect(text, contains('Pagina A'));
    expect(text, contains('Pagina B'));
    expect(text, contains('Pagina C'));
  });

  test('pageIndexes filtra solo las páginas seleccionadas, en orden', () async {
    final document = Document(
      pages: <DocumentPage>[
        _page(blocks: <DocumentBlock>[_paragraph('Pagina A')]),
        _page(blocks: <DocumentBlock>[_paragraph('Pagina B')]),
        _page(blocks: <DocumentBlock>[_paragraph('Pagina C')]),
      ],
      omissions: const <DocumentOmission>{},
    );

    final result = await _export(
      tempDirectory.path,
      document,
      pageIndexes: const <int>[0, 2],
    );
    expect(result.failedCount, 0);

    final text = _extractAllText(File(result.writtenFiles.single));
    expect(text, contains('Pagina A'));
    expect(text, contains('Pagina C'));
    expect(text, isNot(contains('Pagina B')));
  });

  test(
    'una imagen incrustada en un run del cuerpo se dibuja en el PDF',
    () async {
      final document = _pageDocument(
        blocks: <DocumentBlock>[_imageParagraph()],
      );

      final result = await _export(tempDirectory.path, document);

      expect(result.failedCount, 0);
      expect(result.errors, isEmpty);
      final bytes = File(result.writtenFiles.single).readAsBytesSync();
      expect(_containsImageObject(bytes), isTrue);
    },
  );

  test(
    'una imagen en el encabezado y el pie del documento se dibuja en el PDF',
    () async {
      final document = Document(
        pages: <DocumentPage>[
          _page(blocks: <DocumentBlock>[_paragraph('Cuerpo sin imagen')]),
        ],
        omissions: const <DocumentOmission>{},
        header: <DocumentBlock>[_imageParagraph()],
        footer: <DocumentBlock>[_imageParagraph()],
      );

      final result = await _export(tempDirectory.path, document);

      expect(result.failedCount, 0);
      expect(result.errors, isEmpty);
      final bytes = File(result.writtenFiles.single).readAsBytesSync();
      expect(_containsImageObject(bytes), isTrue);
    },
  );

  test(
    'un párrafo con alignment.end queda más a la derecha que uno start',
    () async {
      final document = _pageDocument(
        widthPoints: 600,
        heightPoints: 300,
        blocks: <DocumentBlock>[
          _alignedParagraph('Izquierda', DocumentAlignment.start),
          _alignedParagraph('Derecha', DocumentAlignment.end),
        ],
      );

      final result = await _export(tempDirectory.path, document);
      expect(result.failedCount, 0);

      final lines = _extractLines(File(result.writtenFiles.single));
      final left = lines.firstWhere((line) => line.text.contains('Izquierda'));
      final right = lines.firstWhere((line) => line.text.contains('Derecha'));

      expect(right.bounds.left, greaterThan(left.bounds.left + 100));
    },
  );

  test('indentLeftPoints desplaza el párrafo hacia la derecha', () async {
    final document = _pageDocument(
      widthPoints: 600,
      blocks: <DocumentBlock>[
        _paragraph('SinSangria'),
        _indentedParagraph('ConSangria', indentLeftPoints: 100),
      ],
    );

    final result = await _export(tempDirectory.path, document);
    expect(result.failedCount, 0);

    final lines = _extractLines(File(result.writtenFiles.single));
    final plain = lines.firstWhere((line) => line.text.contains('SinSangria'));
    final indented = lines.firstWhere(
      (line) => line.text.contains('ConSangria'),
    );

    expect(indented.bounds.left, greaterThan(plain.bounds.left + 50));
  });

  test(
    'lineSpacingMultiple mayor separa más las líneas envueltas del párrafo',
    () async {
      final tripleDirectory = await tempDirectory.createTemp('triple_');

      final singleSpaced = await _export(
        tempDirectory.path,
        _pageDocument(
          widthPoints: 220,
          heightPoints: 400,
          blocks: <DocumentBlock>[
            _wrappingParagraph(lineSpacingMultiple: null),
          ],
        ),
      );
      final tripleSpaced = await _export(
        tripleDirectory.path,
        _pageDocument(
          widthPoints: 220,
          heightPoints: 400,
          blocks: <DocumentBlock>[_wrappingParagraph(lineSpacingMultiple: 3)],
        ),
      );

      expect(singleSpaced.failedCount, 0);
      expect(tripleSpaced.failedCount, 0);

      final singleGap = _firstLineGap(File(singleSpaced.writtenFiles.single));
      final tripleGap = _firstLineGap(File(tripleSpaced.writtenFiles.single));

      expect(tripleGap, greaterThan(singleGap * 2));
    },
  );
}

Future<ExportResult> _export(
  String destinationFolder,
  Document document, {
  List<int>? pageIndexes,
}) {
  final command = PdfExportCommand(
    destinationFolder: destinationFolder,
    filenamePattern: const FilenamePattern(
      blocks: <FilenamePatternBlock>[FilenameTextBlock('doc')],
    ),
    rowIndexes: const <int>[0],
    buildDocument: (row) => document,
    resolveRow: (rowIndex) async => const <String?>[],
    headers: const <String>[],
    pageIndexes: pageIndexes,
  );

  return command.execute();
}

// Syncfusion's extractor puts each word on its own line; collapse whitespace
// so substring assertions read naturally regardless of line wrapping.
String _extractAllText(File pdfFile) {
  final pdf = PdfDocument(inputBytes: pdfFile.readAsBytesSync());
  try {
    final raw = PdfTextExtractor(pdf).extractText();
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  } finally {
    pdf.dispose();
  }
}

Document _pageDocument({
  required List<DocumentBlock> blocks,
  double widthPoints = 612,
  double heightPoints = 792,
}) {
  return Document(
    pages: <DocumentPage>[
      _page(
        blocks: blocks,
        widthPoints: widthPoints,
        heightPoints: heightPoints,
      ),
    ],
    omissions: const <DocumentOmission>{},
  );
}

DocumentPage _page({
  required List<DocumentBlock> blocks,
  double widthPoints = 612,
  double heightPoints = 792,
}) {
  return DocumentPage(
    number: 1,
    widthPoints: widthPoints,
    heightPoints: heightPoints,
    margins: const DocumentMargins(
      topPoints: 20,
      rightPoints: 20,
      bottomPoints: 20,
      leftPoints: 20,
    ),
    blocks: blocks,
  );
}

DocumentBlock _paragraph(String text) {
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

DocumentBlock _table(List<List<String>> rows) {
  return DocumentBlock.table(
    DocumentTable(
      rows: <DocumentTableRow>[
        for (final row in rows)
          DocumentTableRow(
            cells: <DocumentTableCell>[
              for (final cellText in row)
                DocumentTableCell(
                  blocks: <DocumentBlock>[_paragraph(cellText)],
                ),
            ],
          ),
      ],
    ),
  );
}

DocumentBlock _imageParagraph({double width = 40, double height = 30}) {
  return DocumentBlock.paragraph(
    DocumentParagraph(
      runs: <DocumentRun>[
        DocumentRun(
          text: '',
          isBold: false,
          isItalic: false,
          isUnderlined: false,
          image: DocumentImage(
            bytes: Uint8List.fromList(_onePixelPngBytes),
            widthPoints: width,
            heightPoints: height,
          ),
        ),
      ],
    ),
  );
}

DocumentBlock _alignedParagraph(String text, DocumentAlignment alignment) {
  return DocumentBlock.paragraph(
    DocumentParagraph(
      alignment: alignment,
      runs: <DocumentRun>[
        DocumentRun(
          text: text,
          isBold: false,
          isItalic: false,
          isUnderlined: false,
          fontSizePoints: 12,
        ),
      ],
    ),
  );
}

DocumentBlock _indentedParagraph(
  String text, {
  required double indentLeftPoints,
}) {
  return DocumentBlock.paragraph(
    DocumentParagraph(
      indentLeftPoints: indentLeftPoints,
      runs: <DocumentRun>[
        DocumentRun(
          text: text,
          isBold: false,
          isItalic: false,
          isUnderlined: false,
          fontSizePoints: 12,
        ),
      ],
    ),
  );
}

// Texto sin espacios largo a propósito: en una columna angosta (180pt de
// ancho de contenido) fuerza el ajuste de línea a varias líneas de forma
// determinística, sin depender de dónde caigan los espacios entre palabras.
DocumentBlock _wrappingParagraph({required double? lineSpacingMultiple}) {
  return DocumentBlock.paragraph(
    DocumentParagraph(
      lineSpacingMultiple: lineSpacingMultiple,
      runs: <DocumentRun>[
        const DocumentRun(
          text:
              'Lorem ipsum dolor sit amet consectetur adipiscing elit '
              'sed do eiusmod tempor incididunt ut labore et dolore magna',
          isBold: false,
          isItalic: false,
          isUnderlined: false,
          fontSizePoints: 12,
        ),
      ],
    ),
  );
}

List<TextLine> _extractLines(File pdfFile) {
  final pdf = PdfDocument(inputBytes: pdfFile.readAsBytesSync());
  try {
    return PdfTextExtractor(pdf).extractTextLines();
  } finally {
    pdf.dispose();
  }
}

/// Distancia vertical entre las dos primeras líneas envueltas del párrafo,
/// ordenadas de arriba hacia abajo (bounds.top crece hacia abajo de página).
double _firstLineGap(File pdfFile) {
  final lines = _extractLines(pdfFile)
    ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
  expect(
    lines.length,
    greaterThanOrEqualTo(2),
    reason: 'el párrafo de prueba debe envolver a al menos 2 líneas',
  );
  return lines[1].bounds.top - lines[0].bounds.top;
}

bool _containsImageObject(Uint8List bytes) {
  // El escritor de bajo nivel de `pdf` (pdf-3.11.1 lib/src/pdf/obj/image.dart)
  // declara cada XObject de imagen con el tipo literal `/Image`; latin1
  // decodifica cualquier byte 1:1 así que es seguro sobre datos binarios.
  return latin1.decode(bytes, allowInvalid: true).contains('/Image');
}

const _onePixelPngBytes = <int>[
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
