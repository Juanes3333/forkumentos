import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:forkumentos/core/commands/cancellable_command.dart';
import 'package:forkumentos/features/export/data/docx_zip_exporter.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:forkumentos/features/export/domain/export_result.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';
import 'package:path/path.dart' as p;

/// Exports one DOCX per row by mutating a once-decoded template ZIP.
final class DocxExportCommand extends CancellableCommand<ExportResult> {
  DocxExportCommand({
    required this.templateBytes,
    required this.destinationFolder,
    required this.filenamePattern,
    required this.rowIndexes,
    required this.placeholders,
    required this.resolveRow,
    required this.headers,
    required this.templateBaseName,
  });

  final Uint8List templateBytes;
  final String destinationFolder;
  final FilenamePattern filenamePattern;
  final List<int> rowIndexes;
  final List<ExportPlaceholder> placeholders;
  final Future<List<String?>> Function(int rowIndex) resolveRow;
  final List<String> headers;
  final String templateBaseName;

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
    final pending = <_DocxRowExportJob>[];

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
          label: 'Preparando DOCX ${index + 1} de $total',
          elapsed: DateTime.now().difference(started),
        ),
      );

      try {
        final row = await resolveRow(rowIndex);
        if (isCancelled) {
          skipped += total - index;
          break;
        }
        final baseName = FilenamePattern.dedupe(
          filenamePattern.resolve(
            row: row,
            headers: headers,
            templateName: templateBaseName,
          ),
          _usedNames,
        );
        _usedNames.add(baseName.toLowerCase());
        final outputPath = p.join(destinationFolder, '$baseName.docx');

        final replacements = <DocxTextReplacement>[];
        final listReplacements = <DocxListReplacement>[];
        final rangeReplacements = <DocxRangeReplacement>[];
        for (final placeholder in placeholders) {
          final value = _valueFor(placeholder.fieldIndex, row);
          final rootStep = placeholder.steps.length == 1
              ? placeholder.steps.first
              : null;
          final endBlockIndex = placeholder.endBlockIndex;
          if (endBlockIndex != null && rootStep is ExportRootBlockStep) {
            rangeReplacements.add(
              DocxRangeReplacement(
                startBlockIndex: rootStep.blockIndex,
                startOffset: placeholder.startOffset,
                endBlockIndex: endBlockIndex,
                endOffset: placeholder.endOffset,
                text: value,
              ),
            );
            continue;
          }
          if (placeholder.isListField && rootStep is ExportRootBlockStep) {
            listReplacements.add(
              DocxListReplacement(
                rootBlockIndex: rootStep.blockIndex,
                lines: value
                    .split('\n')
                    .where((line) => line.trim().isNotEmpty)
                    .toList(),
                isNumberedList: true,
              ),
            );
            continue;
          }
          final paragraphSpan = placeholder.paragraphSpan;
          if (paragraphSpan != null &&
              paragraphSpan > 1 &&
              rootStep is ExportRootBlockStep) {
            listReplacements.add(
              DocxListReplacement(
                rootBlockIndex: rootStep.blockIndex,
                lines: value.split('\n'),
                isNumberedList: false,
                paragraphSpan: paragraphSpan,
              ),
            );
            continue;
          }
          replacements.add(
            DocxTextReplacement(
              steps: placeholder.steps,
              startOffset: placeholder.startOffset,
              endOffset: placeholder.endOffset,
              text: value,
            ),
          );
        }

        pending.add(
          _DocxRowExportJob(
            outputPath: outputPath,
            replacements: replacements,
            listReplacements: listReplacements,
            rangeReplacements: rangeReplacements,
          ),
        );
      } on Object catch (error) {
        failed++;
        errors.add('Fila ${rowIndex + 1}: $error');
      }
    }

    if (pending.isNotEmpty) {
      onProgress?.call(
        CommandProgressEvent(
          current: 0,
          total: total,
          label: 'Generando ${pending.length} DOCX…',
          elapsed: DateTime.now().difference(started),
        ),
      );

      try {
        // One Isolate.run for prepare + apply + write: avoids sharing prepared
        // archive buffers across repeated isolate transfers.
        final paths = await Isolate.run(
          () =>
              _exportPreparedBatch(templateBytes: templateBytes, jobs: pending),
        );
        written.addAll(paths);
        exported += paths.length;
      } on Object catch (error) {
        failed += pending.length;
        errors.add('Lote DOCX: $error');
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

final class _DocxRowExportJob {
  const _DocxRowExportJob({
    required this.outputPath,
    required this.replacements,
    required this.listReplacements,
    required this.rangeReplacements,
  });

  final String outputPath;
  final List<DocxTextReplacement> replacements;
  final List<DocxListReplacement> listReplacements;
  final List<DocxRangeReplacement> rangeReplacements;
}

List<String> _exportPreparedBatch({
  required Uint8List templateBytes,
  required List<_DocxRowExportJob> jobs,
}) {
  const exporter = DocxZipExporter();
  final prepared = exporter.prepare(templateBytes);
  final written = <String>[];

  for (final job in jobs) {
    final bytes = exporter.applyPrepared(
      prepared: prepared,
      replacements: job.replacements,
      listReplacements: job.listReplacements,
      rangeReplacements: job.rangeReplacements,
    );
    File(job.outputPath).writeAsBytesSync(bytes);
    written.add(job.outputPath);
  }

  return written;
}
