import 'dart:io';
import 'dart:typed_data';

import 'package:forkumentos/shared/data/document_repository.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

const _defaultMarginPoints = 72.0;

/// Loads selectable PDF text into the shared [Document] model.
///
/// ponytail: newline-split paragraphs only — no absolute layout, tables, or
/// fonts from the PDF. Upgrade with TextLine geometry if mapping needs it.
final class PdfDocumentRepository implements DocumentRepository {
  const PdfDocumentRepository();

  @override
  Future<Document> load(String filePath) async {
    final normalizedExtension = p.extension(filePath).toLowerCase();
    if (normalizedExtension != '.pdf') {
      throw const FormatException('Selecciona un archivo con extensión .pdf.');
    }

    final bytes = await File(filePath).readAsBytes();
    return _documentFromPdfBytes(bytes);
  }
}

Document _documentFromPdfBytes(Uint8List bytes) {
  late final PdfDocument pdf;
  try {
    pdf = PdfDocument(inputBytes: bytes);
  } catch (_) {
    throw const FormatException('El archivo no es un PDF válido.');
  }

  try {
    if (pdf.pages.count == 0) {
      throw const FormatException('El PDF no contiene páginas.');
    }

    final extractor = PdfTextExtractor(pdf);
    final pages = <DocumentPage>[];

    for (var pageIndex = 0; pageIndex < pdf.pages.count; pageIndex++) {
      final page = pdf.pages[pageIndex];
      final size = page.size;
      final text = extractor.extractText(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );
      final lines = text
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trimRight())
          .where((line) => line.trim().isNotEmpty)
          .toList(growable: false);

      final blocks = lines.isEmpty
          ? <DocumentBlock>[
              const DocumentBlock.paragraph(
                DocumentParagraph(
                  runs: <DocumentRun>[
                    DocumentRun(
                      text: '',
                      isBold: false,
                      isItalic: false,
                      isUnderlined: false,
                    ),
                  ],
                ),
              ),
            ]
          : <DocumentBlock>[
              for (final line in lines)
                DocumentBlock.paragraph(
                  DocumentParagraph(
                    runs: <DocumentRun>[
                      DocumentRun(
                        text: line,
                        isBold: false,
                        isItalic: false,
                        isUnderlined: false,
                      ),
                    ],
                  ),
                ),
            ];

      pages.add(
        DocumentPage(
          number: pageIndex + 1,
          widthPoints: size.width,
          heightPoints: size.height,
          margins: const DocumentMargins(
            topPoints: _defaultMarginPoints,
            rightPoints: _defaultMarginPoints,
            bottomPoints: _defaultMarginPoints,
            leftPoints: _defaultMarginPoints,
          ),
          blocks: blocks,
        ),
      );
    }

    return Document(pages: pages, omissions: const <DocumentOmission>{});
  } finally {
    pdf.dispose();
  }
}
