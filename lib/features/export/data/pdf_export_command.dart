import 'dart:io';
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
/// headers, images, or Word layout. Upgrade with richer pdf widgets when
/// needed.
final class PdfExportCommand extends CancellableCommand<ExportResult> {
  PdfExportCommand({
    required this.destinationFolder,
    required this.filenamePattern,
    required this.rowIndexes,
    required this.buildDocument,
    required this.resolveRow,
    required this.headers,
  });

  final String destinationFolder;
  final FilenamePattern filenamePattern;
  final List<int> rowIndexes;
  final Document Function(List<String?> row) buildDocument;
  final Future<List<String?>> Function(int rowIndex) resolveRow;
  final List<String> headers;

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

        final bytes = await _renderPdf(document);
        await File(outputPath).writeAsBytes(bytes);
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

  Future<Uint8List> _renderPdf(Document document) async {
    final pdf = pw.Document();
    for (final page in document.pages) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(page.widthPoints, page.heightPoints),
          margin: pw.EdgeInsets.fromLTRB(
            page.margins.leftPoints,
            page.margins.topPoints,
            page.margins.rightPoints,
            page.margins.bottomPoints,
          ),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                for (final block in page.blocks) _blockWidget(block),
              ],
            );
          },
        ),
      );
    }
    return pdf.save();
  }

  pw.Widget _blockWidget(DocumentBlock block) {
    return switch (block) {
      DocumentParagraphBlock(:final paragraph) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
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
                  ),
                ),
            ],
          ),
        ),
      ),
      DocumentTableBlock(:final table) => pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        children: <pw.TableRow>[
          for (final row in table.rows)
            pw.TableRow(
              children: <pw.Widget>[
                for (final cell in row.cells)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        for (final nested in cell.blocks) _blockWidget(nested),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    };
  }
}
