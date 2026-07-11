import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:forkumentos/core/commands/cancellable_command.dart';
import 'package:forkumentos/features/export/data/docx_zip_exporter.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:forkumentos/features/export/domain/export_result.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';
import 'package:path/path.dart' as p;

/// Exports one DOCX per row by mutating the template ZIP in an isolate.
final class DocxExportCommand extends CancellableCommand<ExportResult> {
  DocxExportCommand({
    required this.templateBytes,
    required this.destinationFolder,
    required this.filenamePattern,
    required this.rowIndexes,
    required this.placeholders,
    required this.resolveRow,
    required this.headers,
  });

  final Uint8List templateBytes;
  final String destinationFolder;
  final FilenamePattern filenamePattern;
  final List<int> rowIndexes;
  final List<ExportPlaceholder> placeholders;
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
          label: 'Generando DOCX ${index + 1} de $total',
          elapsed: DateTime.now().difference(started),
        ),
      );

      try {
        final row = await resolveRow(rowIndex);
        final baseName = FilenamePattern.dedupe(
          filenamePattern.resolve(row: row, headers: headers),
          _usedNames,
        );
        _usedNames.add(baseName.toLowerCase());
        final outputPath = p.join(destinationFolder, '$baseName.docx');

        final replacements = <DocxTextReplacement>[
          for (final placeholder in placeholders)
            DocxTextReplacement(
              pageIndex: placeholder.pageIndex,
              steps: placeholder.steps,
              startOffset: placeholder.startOffset,
              endOffset: placeholder.endOffset,
              text: _valueFor(placeholder.fieldIndex, row),
            ),
        ];

        await Isolate.run(() {
          final bytes = const DocxZipExporter().applyReplacements(
            templateBytes: templateBytes,
            replacements: replacements,
          );
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
        label: isCancelled ? 'Exportación cancelada' : 'DOCX completado',
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

  String _valueFor(int fieldIndex, List<String?> row) {
    if (fieldIndex < 0 || fieldIndex >= row.length) {
      return '';
    }
    return row[fieldIndex] ?? '';
  }
}
