import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/commands/cancellable_command.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/export/data/docx_export_command.dart';
import 'package:forkumentos/features/export/data/export_zip_writer.dart';
import 'package:forkumentos/features/export/data/pdf_export_command.dart';
import 'package:forkumentos/features/export/domain/export_job.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:forkumentos/features/export/domain/export_progress.dart';
import 'package:forkumentos/features/export/domain/export_result.dart';
import 'package:forkumentos/features/export/presentation/export_dialog.dart';
import 'package:forkumentos/features/export/presentation/export_progress_dialog.dart';
import 'package:forkumentos/features/export/presentation/export_summary_dialog.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_provider.dart';
import 'package:forkumentos/features/preview/data/preview_record_repository.dart';
import 'package:forkumentos/features/preview/domain/preview_document.dart';
import 'package:forkumentos/features/preview/presentation/preview_state_provider.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/document_content_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

/// Orchestrates export across mapping/template/datasource/preview/export.
///
/// Features must not import each other; this routing layer is the seam.
Future<void> launchExport(
  BuildContext context,
  WidgetRef ref, {
  required bool pickDestination,
}) async {
  final project = ref.read(activeProjectProvider).valueOrNull;
  if (project == null) {
    return;
  }

  final template = ref.read(activeTemplateProvider).valueOrNull;
  final datasource = ref.read(activeDatasourceProvider).valueOrNull;
  if (template == null || datasource == null) {
    await _showBlocked(
      context,
      'Se necesitan una plantilla y una fuente de datos para exportar.',
    );
    return;
  }

  final review = ref.read(mappingReviewProvider);
  if (review != null &&
      (review.overlappingAssignmentPairs.isNotEmpty ||
          review.invalidAssignments.isNotEmpty ||
          review.duplicateAssignments.isNotEmpty)) {
    await _showBlocked(
      context,
      'Corrige solapes, asignaciones inválidas o IDs duplicados '
      'antes de exportar.',
    );
    return;
  }

  final paths = ref.read(workspacePathsProvider);
  if (paths == null) {
    return;
  }

  late final String destinationFolder;
  if (pickDestination) {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Seleccionar carpeta de exportación',
    );
    if (selected == null) {
      return;
    }
    destinationFolder = selected;
  } else {
    destinationFolder = paths.exportFolder(project.name);
  }

  await Directory(destinationFolder).create(recursive: true);

  final previewState = ref.read(previewStateProvider);
  final sampleRow =
      ref.read(previewRecordProvider).valueOrNull ?? datasource.previewRow;

  if (!context.mounted) {
    return;
  }

  final dialogResult = await ExportDialog.show(
    context,
    destinationFolder: destinationFolder,
    headers: datasource.headers,
    sampleRow: sampleRow,
    rowCount: datasource.rowCount,
    currentRowIndex: previewState.rowIndex.clamp(
      0,
      datasource.rowCount > 0 ? datasource.rowCount - 1 : 0,
    ),
    missingFieldHeaders: review?.missingFieldHeaders ?? const <String>[],
  );
  if (dialogResult == null || !context.mounted) {
    return;
  }

  final job = dialogResult.job;
  final assignments = ref.read(activeMappingProvider).state.assignments;
  final placeholders = assignments.map(_toPlaceholder).toList();
  final baseDocument = await ref.read(
    documentContentProvider(template.sourcePath).future,
  );
  final templateBytes = await File(template.sourcePath).readAsBytes();
  final recordRepository = ref.read(previewRecordRepositoryProvider);

  Future<List<String?>> resolveRow(int rowIndex) {
    return recordRepository.readRecord(
      datasource: datasource,
      rowIndex: rowIndex,
    );
  }

  Document buildMerged(List<String?> row) {
    if (assignments.isEmpty) {
      return baseDocument;
    }
    return buildPreviewDocument(
      document: baseDocument,
      assignments: assignments,
      headers: datasource.headers,
      row: row,
    );
  }

  final session = ExportSession();
  final progressNotifier = ValueNotifier<ExportProgress>(
    ExportProgress(current: 0, total: job.rowIndexes.length),
  );

  if (!context.mounted) {
    return;
  }

  // ignore: unawaited_futures
  ExportProgressDialog.show(
    context,
    progressNotifier: progressNotifier,
    onCancel: session.cancel,
  );

  final result = await session.run(
    job: job,
    templateBytes: Uint8List.fromList(templateBytes),
    placeholders: placeholders,
    headers: datasource.headers,
    resolveRow: resolveRow,
    buildDocument: buildMerged,
    onProgress: (progress) {
      progressNotifier.value = progress;
    },
  );

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  progressNotifier.dispose();
  if (context.mounted) {
    await ExportSummaryDialog.show(context, result);
  }
}

ExportPlaceholder _toPlaceholder(FieldAssignment assignment) {
  return ExportPlaceholder(
    pageIndex: assignment.path.pageIndex,
    steps: <ExportPathStep>[
      for (final step in assignment.path.steps) _toExportStep(step),
    ],
    startOffset: assignment.startOffset,
    endOffset: assignment.endOffset,
    fieldIndex: assignment.fieldIndex,
  );
}

ExportPathStep _toExportStep(DocumentPathStep step) {
  return switch (step) {
    RootDocumentBlockStep(:final blockIndex) => ExportPathStep.rootBlock(
      blockIndex: blockIndex,
    ),
    DocumentTableCellBlockStep(
      :final rowIndex,
      :final cellIndex,
      :final blockIndex,
    ) =>
      ExportPathStep.cellBlock(
        rowIndex: rowIndex,
        cellIndex: cellIndex,
        blockIndex: blockIndex,
      ),
  };
}

Future<void> _showBlocked(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Exportación bloqueada'),
      content: Text(message),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

/// Drives format commands, cancel, ZIP, and aggregated progress.
final class ExportSession {
  CancellableCommand<ExportResult>? _active;

  void cancel() {
    _active?.cancel();
  }

  Future<ExportResult> run({
    required ExportJob job,
    required Uint8List templateBytes,
    required List<ExportPlaceholder> placeholders,
    required List<String> headers,
    required Future<List<String?>> Function(int rowIndex) resolveRow,
    required Document Function(List<String?> row) buildDocument,
    required void Function(ExportProgress progress) onProgress,
  }) async {
    final started = DateTime.now();
    final written = <String>[];
    final errors = <String>[];
    var exported = 0;
    var failed = 0;
    var skipped = 0;
    var cancelled = false;

    final formats = switch (job.format) {
      ExportFormat.docx => <_FormatKind>[_FormatKind.docx],
      ExportFormat.pdf => <_FormatKind>[_FormatKind.pdf],
      ExportFormat.both => <_FormatKind>[_FormatKind.docx, _FormatKind.pdf],
    };

    final totalUnits = job.rowIndexes.length * formats.length;
    var completedUnits = 0;

    void emit(String label) {
      onProgress(
        ExportProgress(
          current: completedUnits,
          total: totalUnits,
          label: label,
          elapsed: DateTime.now().difference(started),
        ),
      );
    }

    for (final format in formats) {
      if (cancelled) {
        break;
      }

      if (format == _FormatKind.docx) {
        final command = DocxExportCommand(
          templateBytes: templateBytes,
          destinationFolder: job.destinationFolder,
          filenamePattern: job.filenamePattern,
          rowIndexes: job.rowIndexes,
          placeholders: placeholders,
          resolveRow: resolveRow,
          headers: headers,
        );
        _active = command;
        final partial = await command.execute(
          onProgress: (event) {
            completedUnits = event.current;
            emit(event.label ?? 'Generando DOCX…');
          },
        );
        written.addAll(partial.writtenFiles);
        exported += partial.exportedCount;
        failed += partial.failedCount;
        skipped += partial.skippedCount;
        errors.addAll(partial.errors);
        cancelled = partial.cancelled;
        completedUnits = job.rowIndexes.length;
      } else {
        final command = PdfExportCommand(
          destinationFolder: job.destinationFolder,
          filenamePattern: job.filenamePattern,
          rowIndexes: job.rowIndexes,
          buildDocument: buildDocument,
          resolveRow: resolveRow,
          headers: headers,
        );
        _active = command;
        final baseOffset = formats.first == _FormatKind.docx
            ? job.rowIndexes.length
            : 0;
        final partial = await command.execute(
          onProgress: (event) {
            completedUnits = baseOffset + event.current;
            emit(event.label ?? 'Generando PDF…');
          },
        );
        written.addAll(partial.writtenFiles);
        exported += partial.exportedCount;
        failed += partial.failedCount;
        skipped += partial.skippedCount;
        errors.addAll(partial.errors);
        cancelled = partial.cancelled || cancelled;
        completedUnits = baseOffset + job.rowIndexes.length;
      }
    }

    String? zipPath;
    if (job.createZip && written.isNotEmpty) {
      emit('Creando ZIP…');
      final zipName = p.join(
        job.destinationFolder,
        'export_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      zipPath = await const ExportZipWriter().writeZip(
        zipPath: zipName,
        filePaths: written,
      );
    }

    emit(cancelled ? 'Exportación cancelada' : 'Exportación completada');

    return ExportResult(
      exportedCount: exported,
      failedCount: failed,
      skippedCount: skipped,
      destinationFolder: job.destinationFolder,
      writtenFiles: written,
      zipPath: zipPath,
      cancelled: cancelled,
      errors: errors,
    );
  }
}

enum _FormatKind { docx, pdf }
