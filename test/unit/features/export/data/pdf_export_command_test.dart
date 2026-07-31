import 'dart:io';

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

  test('una página cuyo contenido excede el alto nominal no lanza excepción '
      'y fluye a una hoja de continuación', () async {
    // Small nominal page height with far more paragraph content than fits
    // — before the pw.MultiPage fix this would silently clip under pw.Page.
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
      expect(
        pdf.pages.count,
        greaterThan(1),
        reason: 'overflow content should spill onto a continuation page',
      );
    } finally {
      pdf.dispose();
    }
  });

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

    // Un solo MultiPage consolida bloques; el conteo de hojas lo decide el
    // layout de pdf, no 1:1 con DocumentPage. Verificamos el contenido.
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
