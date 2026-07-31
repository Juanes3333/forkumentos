import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:forkumentos/core/commands/cancellable_command.dart';
import 'package:forkumentos/features/export/domain/export_result.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders a merged [Document] to PDF.
///
/// ponytail: fidelity ceiling vs DOCX — simple paragraphs/tables only; no
/// images or Word layout. Upgrade with richer pdf widgets when needed.
final class PdfExportCommand extends CancellableCommand<ExportResult> {
  PdfExportCommand({
    required this.destinationFolder,
    required this.filenamePattern,
    required this.rowIndexes,
    required this.buildDocument,
    required this.resolveRow,
    required this.headers,
    this.pageIndexes,
  });

  final String destinationFolder;
  final FilenamePattern filenamePattern;
  final List<int> rowIndexes;
  final Document Function(List<String?> row) buildDocument;
  final Future<List<String?>> Function(int rowIndex) resolveRow;
  final List<String> headers;

  /// 0-based page indexes to export, in document order. `null` or empty
  /// exports every page.
  final List<int>? pageIndexes;

  final Set<String> _usedNames = <String>{};

  @override
  Future<ExportResult> execute({
    void Function(CommandProgressEvent event)? onProgress,
  }) async {
    final started = DateTime.now();
    final written = <String>[];
    final errors = <String>[];
    var exported = 0;
    var failed = 0;
    var skipped = 0;
    final total = rowIndexes.length;

    for (var index = 0; index < rowIndexes.length; index++) {
      if (isCancelled) {
        skipped += total - index;
        break;
      }

      final rowIndex = rowIndexes[index];
      onProgress?.call(
        CommandProgressEvent(
          current: index,
          total: total,
          label: 'Generando PDF ${index + 1} de $total',
          elapsed: DateTime.now().difference(started),
        ),
      );

      try {
        final row = await resolveRow(rowIndex);
        final document = buildDocument(row);
        final baseName = FilenamePattern.dedupe(
          filenamePattern.resolve(row: row, headers: headers),
          _usedNames,
        );
        _usedNames.add(baseName.toLowerCase());
        final outputPath = p.join(destinationFolder, '$baseName.pdf');

        await Isolate.run(() async {
          final bytes = await _renderPdfBytes(document, pageIndexes);
          File(outputPath).writeAsBytesSync(bytes);
        });
        written.add(outputPath);
        exported++;
      } on Object catch (error) {
        failed++;
        errors.add('Fila ${rowIndex + 1}: $error');
      }
    }

    onProgress?.call(
      CommandProgressEvent(
        current: exported + failed,
        total: total,
        label: isCancelled ? 'Exportación cancelada' : 'PDF completado',
        elapsed: DateTime.now().difference(started),
      ),
    );

    return ExportResult(
      exportedCount: exported,
      failedCount: failed,
      skippedCount: skipped,
      destinationFolder: destinationFolder,
      writtenFiles: written,
      cancelled: isCancelled,
      errors: errors,
    );
  }
}

Future<Uint8List> _renderPdfBytes(Document document, List<int>? pageIndexes) {
  final pdf = pw.Document();
  final selectedPages = pageIndexes == null || pageIndexes.isEmpty
      ? document.pages
      : <DocumentPage>[
          for (final index in pageIndexes)
            if (index >= 0 && index < document.pages.length)
              document.pages[index],
        ];

  final header = document.header.isEmpty
      ? null
      : _pdfHeaderFooterBuilder(document.header);
  final footer = document.footer.isEmpty
      ? null
      : _pdfHeaderFooterBuilder(document.footer);

  if (selectedPages.isEmpty) {
    return pdf.save();
  }
  final firstPage = selectedPages.first;

  // ponytail: un solo MultiPage para todo el documento. Un MultiPage por
  // DocumentPage forzaba doble paginación (nuestra + la de pdf) y hojas
  // casi en blanco. Ceiling: pageFormat/margins salen de la primera página
  // seleccionada; si un doc mezcla tamaños, hay que volver a per-page.
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat(firstPage.widthPoints, firstPage.heightPoints),
      margin: pw.EdgeInsets.fromLTRB(
        firstPage.margins.leftPoints,
        firstPage.margins.topPoints,
        firstPage.margins.rightPoints,
        firstPage.margins.bottomPoints,
      ),
      header: header,
      footer: footer,
      build: (context) => <pw.Widget>[
        for (final page in selectedPages)
          for (final block in page.blocks) _pdfBlockWidget(block),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget Function(pw.Context) _pdfHeaderFooterBuilder(
  List<DocumentBlock> blocks,
) {
  return (context) => pw.DefaultTextStyle.merge(
    style: const pw.TextStyle(fontSize: 9),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[for (final block in blocks) _pdfBlockWidget(block)],
    ),
  );
}

pw.Widget _pdfBlockWidget(DocumentBlock block) {
  return switch (block) {
    DocumentParagraphBlock(:final paragraph) => pw.Padding(
      padding: pw.EdgeInsets.only(
        top: paragraph.spacingBeforePoints,
        bottom: paragraph.spacingAfterPoints,
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: <pw.TextSpan>[
            for (final run in paragraph.runs)
              pw.TextSpan(
                text: run.text,
                style: pw.TextStyle(
                  fontWeight: run.isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  fontStyle: run.isItalic
                      ? pw.FontStyle.italic
                      : pw.FontStyle.normal,
                  decoration: run.isUnderlined
                      ? pw.TextDecoration.underline
                      : pw.TextDecoration.none,
                  color: _pdfRunColor(run),
                  fontSize: run.fontSizePoints,
                ),
              ),
          ],
        ),
      ),
    ),
    DocumentTableBlock(:final table) => _pdfTableWidget(table),
  };
}

PdfColor? _pdfRunColor(DocumentRun run) {
  final hex = run.colorHex;
  if (hex == null) {
    return null;
  }
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : PdfColor.fromInt(0xFF000000 | value);
}

// ponytail: the DOCX parser doesn't interpret gridSpan/vMerge (see
// docx_document_repository.dart's _serializeTable comment), so a table with
// merged cells in the original produces rows of unequal length here.
// pw.Table requires every row to have the same number of children, so short
// rows are padded to maxColumns with empty cells instead of crashing.
pw.Widget _pdfTableWidget(DocumentTable table) {
  var maxColumns = 0;
  for (final row in table.rows) {
    if (row.cells.length > maxColumns) {
      maxColumns = row.cells.length;
    }
  }
  if (maxColumns == 0) {
    return pw.SizedBox.shrink();
  }

  return pw.Table(
    border: pw.TableBorder.all(width: 0.5),
    children: <pw.TableRow>[
      for (final row in table.rows)
        pw.TableRow(
          children: <pw.Widget>[
            for (var cellIndex = 0; cellIndex < maxColumns; cellIndex++)
              if (cellIndex < row.cells.length)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      for (final nested in row.cells[cellIndex].blocks)
                        _pdfBlockWidget(nested),
                    ],
                  ),
                )
              else
                pw.SizedBox.shrink(),
          ],
        ),
    ],
  );
}
