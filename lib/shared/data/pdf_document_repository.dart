import 'dart:io';
import 'dart:typed_data';

import 'package:forkumentos/shared/data/document_repository.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

const _defaultMarginPoints = 72.0;

/// Minimum gap (points) between words to treat as a new table column.
const _minColumnGapPoints = 18.0;

/// Max horizontal drift (points) when matching column X across rows.
const _columnAlignTolerancePoints = 12.0;

/// Loads selectable PDF text into the shared [Document] model.
///
/// ponytail: heuristic column clustering from TextLine/TextWord bounds — not
/// full PDF table structure. Upgrade with Syncfusion table extraction or
/// tagged-PDF structure if mapping needs real grid fidelity.
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
      final textLines = extractor.extractTextLines(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );
      final blocks = _blocksFromTextLines(textLines);

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

List<DocumentBlock> _blocksFromTextLines(List<TextLine> textLines) {
  final rows = <_PdfVisualRow>[];
  for (final line in textLines) {
    final row = _visualRowFromLine(line);
    if (row == null) {
      continue;
    }
    rows.add(row);
  }

  if (rows.isEmpty) {
    return <DocumentBlock>[_emptyParagraphBlock()];
  }

  final blocks = <DocumentBlock>[];
  var index = 0;
  while (index < rows.length) {
    final row = rows[index];
    if (!_looksMultiColumn(row)) {
      blocks.add(_paragraphBlock(row.cells.map((cell) => cell.text).join(' ')));
      index++;
      continue;
    }

    final tableRows = <_PdfVisualRow>[row];
    var cursor = index + 1;
    while (cursor < rows.length &&
        _looksMultiColumn(rows[cursor]) &&
        _compatibleColumns(tableRows.first, rows[cursor])) {
      tableRows.add(rows[cursor]);
      cursor++;
    }

    blocks.add(_tableBlock(tableRows));
    index = cursor;
  }

  return blocks;
}

_PdfVisualRow? _visualRowFromLine(TextLine line) {
  final words = List<TextWord>.of(line.wordCollection)
    ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
  if (words.isEmpty) {
    final trimmed = line.text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return _PdfVisualRow(
      cells: <_PdfCell>[_PdfCell(text: trimmed, left: line.bounds.left)],
    );
  }

  final cells = <_PdfCell>[];
  var currentTexts = <String>[words.first.text];
  var cellLeft = words.first.bounds.left;
  var previousRight = words.first.bounds.right;

  for (var index = 1; index < words.length; index++) {
    final word = words[index];
    final gap = word.bounds.left - previousRight;
    if (gap >= _minColumnGapPoints) {
      final text = _joinWordTexts(currentTexts);
      if (text.isNotEmpty) {
        cells.add(_PdfCell(text: text, left: cellLeft));
      }
      currentTexts = <String>[word.text];
      cellLeft = word.bounds.left;
    } else {
      currentTexts.add(word.text);
    }
    previousRight = word.bounds.right;
  }

  final lastText = _joinWordTexts(currentTexts);
  if (lastText.isNotEmpty) {
    cells.add(_PdfCell(text: lastText, left: cellLeft));
  }

  if (cells.isEmpty) {
    return null;
  }
  return _PdfVisualRow(cells: cells);
}

bool _looksMultiColumn(_PdfVisualRow row) => row.cells.length >= 2;

bool _compatibleColumns(_PdfVisualRow reference, _PdfVisualRow candidate) {
  if (reference.cells.length != candidate.cells.length) {
    return false;
  }
  for (var index = 0; index < reference.cells.length; index++) {
    final delta = (reference.cells[index].left - candidate.cells[index].left)
        .abs();
    if (delta > _columnAlignTolerancePoints) {
      return false;
    }
  }
  return true;
}

DocumentBlock _tableBlock(List<_PdfVisualRow> rows) {
  return DocumentBlock.table(
    DocumentTable(
      rows: <DocumentTableRow>[
        for (final row in rows)
          DocumentTableRow(
            cells: <DocumentTableCell>[
              for (final cell in row.cells)
                DocumentTableCell(
                  blocks: <DocumentBlock>[_paragraphBlock(cell.text)],
                ),
            ],
          ),
      ],
    ),
  );
}

DocumentBlock _paragraphBlock(String text) {
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

DocumentBlock _emptyParagraphBlock() => _paragraphBlock('');

String _joinWordTexts(List<String> texts) {
  return texts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

final class _PdfVisualRow {
  const _PdfVisualRow({required this.cells});

  final List<_PdfCell> cells;
}

final class _PdfCell {
  const _PdfCell({required this.text, required this.left});

  final String text;
  final double left;
}
