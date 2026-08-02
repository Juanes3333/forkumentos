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
/// ponytail: fidelity ceiling vs DOCX — el texto siempre se dibuja con la
/// fuente por defecto de `pdf` (Helvetica), nunca con la familia real del
/// DOCX (Cambria/Calibri/...): cargar y emparejar TTFs del sistema es una
/// pieza aparte, no incluida aquí. El interlineado sí se calibra 1:1 contra
/// esa fuente real (ver `_pdfLineSpacingPoints`).
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
        left: paragraph.indentLeftPoints,
        right: paragraph.indentRightPoints,
      ),
      // pw.RichText se ajusta a su propio ancho de contenido (ver
      // pdf-3.11.1 lib/src/widgets/text.dart: box.width = constraints
      // .minWidth cuando no hay overflow), así que sin este Align un
      // párrafo end/center quedaría siempre pegado al margen izquierdo:
      // no hay ancho sobrante dentro del cual textAlign pueda mover nada.
      // Align sí ocupa el ancho completo disponible (maxWidth acotado) y
      // reposiciona ahí la caja ya maquetada del texto.
      child: pw.Align(
        alignment: _pdfBlockAlignment(paragraph.alignment),
        child: pw.RichText(
          textAlign: _pdfTextAlign(paragraph.alignment),
          text: pw.TextSpan(children: _pdfParagraphSpans(paragraph)),
        ),
      ),
    ),
    DocumentTableBlock(:final table) => _pdfTableWidget(table),
  };
}

pw.TextAlign _pdfTextAlign(DocumentAlignment alignment) {
  return switch (alignment) {
    DocumentAlignment.start => pw.TextAlign.left,
    DocumentAlignment.center => pw.TextAlign.center,
    DocumentAlignment.end => pw.TextAlign.right,
    DocumentAlignment.justify => pw.TextAlign.justify,
  };
}

// Reposiciona la caja (ya ajustada a su contenido) del párrafo dentro del
// ancho completo disponible. En justify, RichText ya reparte el texto
// dentro de su propia caja; como esa caja se ajusta al ancho de la línea
// envuelta MÁS ANCHA, alinearla a la izquierda dentro del Align es lo más
// cercano al comportamiento real sin forzar un ancho exacto aquí.
pw.Alignment _pdfBlockAlignment(DocumentAlignment alignment) {
  return switch (alignment) {
    DocumentAlignment.start || DocumentAlignment.justify =>
      pw.Alignment.centerLeft,
    DocumentAlignment.center => pw.Alignment.center,
    DocumentAlignment.end => pw.Alignment.centerRight,
  };
}

// Espeja _buildContent de MappingAwareParagraph: sangría de primera línea
// como hueco vacío al inicio del flujo, y un run con imagen se dibuja en el
// punto exacto del flujo de texto que ocupa en vez de perderse en silencio.
List<pw.InlineSpan> _pdfParagraphSpans(DocumentParagraph paragraph) {
  final spans = <pw.InlineSpan>[];

  final firstLineIndent = paragraph.indentFirstLinePoints;
  if (firstLineIndent > 0) {
    spans.add(pw.WidgetSpan(child: pw.SizedBox(width: firstLineIndent)));
  }

  for (final run in paragraph.runs) {
    final image = run.image;
    if (image != null) {
      spans.add(
        pw.WidgetSpan(
          child: pw.Image(
            pw.MemoryImage(image.bytes),
            width: image.widthPoints,
            height: image.heightPoints,
            // Word dibuja la imagen exactamente al tamaño declarado en el
            // DOCX, sin respetar la relación de aspecto del archivo.
            fit: pw.BoxFit.fill,
          ),
        ),
      );
      continue;
    }

    if (run.text.isEmpty) {
      continue;
    }

    spans.add(
      pw.TextSpan(text: run.text, style: _pdfRunStyle(run, paragraph)),
    );
  }

  return spans;
}

pw.TextStyle _pdfRunStyle(DocumentRun run, DocumentParagraph paragraph) {
  final fontSize = run.fontSizePoints;
  return pw.TextStyle(
    fontWeight: run.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    fontStyle: run.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
    decoration: run.isUnderlined
        ? pw.TextDecoration.underline
        : pw.TextDecoration.none,
    color: _pdfRunColor(run),
    fontSize: fontSize,
    // null = sin tamaño propio, no hay base fiable para calcular el
    // interlineado en puntos; se deja el interlineado natural del tema.
    lineSpacing: fontSize == null
        ? null
        : _pdfLineSpacingPoints(paragraph, fontSize),
  );
}

PdfColor? _pdfRunColor(DocumentRun run) {
  final hex = run.colorHex;
  if (hex == null) {
    return null;
  }
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : PdfColor.fromInt(0xFF000000 | value);
}

// Métricas AFM natales de Helvetica (pdf.PdfFont.helvetica: ascent 0.910,
// descent -0.220), la fuente por defecto de `pdf` cuando no se carga un TTF
// propio. `TextStyle.height` no está cableado al layout real de esta versión
// del paquete `pdf` (ver PDF-3.11.1 lib/src/widgets/text.dart, que solo lee
// `style.lineSpacing`); por eso el interlineado se expresa como puntos
// ADITIVOS por línea en vez del factor MULTIPLICATIVO que usa
// MappingAwareParagraph._lineHeightFactor en Flutter.
const _pdfDefaultFontAscent = 0.910;
const _pdfDefaultFontDescent = -0.220;
const _pdfNaturalLineHeightRatio =
    _pdfDefaultFontAscent - _pdfDefaultFontDescent;

/// Puntos extra a sumar por línea (puede ser negativo) para que el
/// interlineado declarado por el DOCX (`w:spacing`) se respete sobre el alto
/// natural de la fuente que el PDF realmente dibuja. `null` = interlineado
/// natural sin ajustar, igual semántica que `_lineHeightFactor` en
/// MappingAwareParagraph.
double? _pdfLineSpacingPoints(
  DocumentParagraph paragraph,
  double fontSizePoints,
) {
  final naturalHeightPoints = fontSizePoints * _pdfNaturalLineHeightRatio;

  final exactPoints = paragraph.lineSpacingExactPoints;
  if (exactPoints != null && fontSizePoints > 0) {
    return exactPoints - naturalHeightPoints;
  }

  final multiple = paragraph.lineSpacingMultiple;
  if (multiple == null || multiple == 1) {
    return null;
  }
  return naturalHeightPoints * (multiple - 1);
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
