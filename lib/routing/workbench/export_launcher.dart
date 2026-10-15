import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/commands/cancellable_command.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/export/data/docx_export_command.dart';
import 'package:forkumentos/features/export/data/export_zip_writer.dart';
import 'package:forkumentos/features/export/domain/export_job.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:forkumentos/features/export/domain/export_progress.dart';
import 'package:forkumentos/features/export/domain/export_result.dart';
import 'package:forkumentos/features/export/presentation/export_dialog.dart';
import 'package:forkumentos/features/export/presentation/export_progress_dialog.dart';
import 'package:forkumentos/features/export/presentation/export_summary_dialog.dart';
import 'package:forkumentos/features/mapping/data/mapping_json.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/header_remap.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_provider.dart';
import 'package:forkumentos/features/preview/data/preview_record_repository.dart';
import 'package:forkumentos/features/preview/presentation/preview_state_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/workbench/multi_template_export.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
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

  final templateBytes = await File(template.sourcePath).readAsBytes();

  if (!context.mounted) {
    return;
  }

  final templateBaseName = p.basenameWithoutExtension(template.fileName);
  final recordRepository = ref.read(previewRecordRepositoryProvider);

  // Con varias plantillas se puede elegir cuáles exportar. El mapeo de las
  // que no están activas se reubica por nombre contra las columnas actuales.
  final others = project.templates.length > 1
      ? _otherTemplates(project, datasource.headers)
      : const <_ParkedTemplate>[];
  final templateChoices = project.templates.length > 1
      ? <ExportTemplateChoice>[
          for (final entry in project.templates)
            (
              id: entry.id,
              name: p.basenameWithoutExtension(
                entry.id == project.activeTemplateId
                    ? template.fileName
                    : entry.fileName,
              ),
            ),
        ]
      : const <ExportTemplateChoice>[];

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
    orphanFieldHeaders: <String>{
      ...?review?.orphanFieldHeaders,
      for (final other in others) ...other.orphanHeaders,
    }.toList(),
    templateChoices: templateChoices,
    templateName: templateBaseName,
    loadRowValues: (rowIndexes) => recordRepository.readRecords(
      datasource: datasource,
      rowIndexes: rowIndexes,
    ),
  );
  if (dialogResult == null || !context.mounted) {
    return;
  }

  final job = dialogResult.job;
  final assignments = ref.read(activeMappingProvider).state.assignments;
  // Guarda independiente de la revisión: nunca se lee una fila con un índice
  // que ya no corresponde al nombre del campo (datos de otra columna).
  if (!assignmentsMatchHeaders(
    assignments: assignments,
    headers: datasource.headers,
  )) {
    await _showBlocked(
      context,
      'Los campos del documento no coinciden con las columnas actuales del '
      'Excel. Usa "Refrescar datos" o vuelve a abrir el proyecto e inténtalo '
      'de nuevo.',
    );
    return;
  }
  final placeholders = assignments.map(_toPlaceholder).toList();
  final rowsByIndex = await recordRepository.readRecords(
    datasource: datasource,
    rowIndexes: job.rowIndexes,
  );

  Future<List<String?>> resolveRow(int rowIndex) async {
    return rowsByIndex[rowIndex] ??
        List<String?>.filled(datasource.headers.length, null);
  }

  final multiTemplate = templateChoices.length > 1;
  final selectedIds = dialogResult.selectedTemplateIds;
  final inputs = <TemplateExportInput>[
    if (multiTemplate)
      for (final choice in templateChoices)
        if (selectedIds.contains(choice.id))
          if (choice.id == project.activeTemplateId)
            (
              name: choice.name,
              bytes: Uint8List.fromList(templateBytes),
              placeholders: placeholders,
            )
          else if (others.where((o) => o.id == choice.id).firstOrNull
              case final parked?)
            (
              name: choice.name,
              bytes: Uint8List.fromList(await File(parked.path).readAsBytes()),
              placeholders: parked.placeholders,
            ),
  ];

  final session = ExportSession();
  final progressNotifier = ValueNotifier<ExportProgress>(
    ExportProgress(
      current: 0,
      total: job.rowIndexes.length * (multiTemplate ? inputs.length : 1),
    ),
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

  void onProgress(ExportProgress progress) {
    progressNotifier.value = progress;
  }

  final result = multiTemplate
      ? await runTemplatesExport(
          session: session,
          job: job,
          templates: inputs,
          headers: datasource.headers,
          resolveRow: resolveRow,
          onProgress: onProgress,
        )
      : await session.run(
          job: job,
          templateBytes: Uint8List.fromList(templateBytes),
          placeholders: placeholders,
          headers: datasource.headers,
          resolveRow: resolveRow,
          onProgress: onProgress,
        );

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  progressNotifier.dispose();
  if (context.mounted) {
    await ExportSummaryDialog.show(context, result);
  }
}

/// Plantilla del proyecto que no es la activa, lista para exportar: su DOCX y
/// su mapeo reubicado por nombre contra las columnas actuales.
typedef _ParkedTemplate = ({
  String id,
  String path,
  List<ExportPlaceholder> placeholders,
  List<String> orphanHeaders,
});

List<_ParkedTemplate> _otherTemplates(Project project, List<String> headers) {
  return <_ParkedTemplate>[
    for (final entry in project.templates)
      if (entry.id != project.activeTemplateId &&
          entry.embeddedPath != null &&
          File(entry.embeddedPath!).existsSync())
        () {
          final remapped = remapAssignmentsToHeaders(
            assignments: mappingAssignmentsFromJson(entry.assignments),
            headers: headers,
          );
          return (
            id: entry.id,
            path: entry.embeddedPath!,
            placeholders: remapped.assignments.map(_toPlaceholder).toList(),
            orphanHeaders: remapped.orphanHeaders,
          );
        }(),
  ];
}

ExportPlaceholder _toPlaceholder(FieldAssignment assignment) {
  return ExportPlaceholder(
    steps: <ExportPathStep>[
      for (final step in assignment.path.steps) _toExportStep(step),
    ],
    startOffset: assignment.startOffset,
    endOffset: assignment.endOffset,
    fieldIndex: assignment.fieldIndex,
    isListField: assignment.isListField,
    endBlockIndex: assignment.endPath == null
        ? null
        : _resolveRootBlockIndex(assignment.endPath!),
  );
}

/// Extrae el `blockIndex` raíz de [path], o `null` si no es un párrafo de
/// nivel raíz (p. ej. una celda de tabla). `endBlockIndex` de
/// [ExportPlaceholder] solo soporta rangos que terminan a nivel raíz.
int? _resolveRootBlockIndex(DocumentTextPath path) {
  if (path.steps.length != 1) {
    return null;
  }
  final step = path.steps.single;
  return step is RootDocumentBlockStep ? step.blockIndex : null;
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
  bool _cancelRequested = false;

  /// `true` si el usuario pidió cancelar (también entre dos plantillas).
  bool get cancelRequested => _cancelRequested;

  void cancel() {
    _cancelRequested = true;
    _active?.cancel();
  }

  /// Exporta una plantilla. Para exportar varias, se llama una vez por
  /// plantilla con [progressOffset] y [progressTotal] (el avance es el de todo
  /// el paquete) y `writeZip: false` (el ZIP único lo arma quien llama).
  Future<ExportResult> run({
    required ExportJob job,
    required Uint8List templateBytes,
    required List<ExportPlaceholder> placeholders,
    required List<String> headers,
    required Future<List<String?>> Function(int rowIndex) resolveRow,
    required void Function(ExportProgress progress) onProgress,
    int progressOffset = 0,
    int? progressTotal,
    bool writeZip = true,
  }) async {
    final started = DateTime.now();
    final written = <String>[];
    final errors = <String>[];
    var exported = 0;
    var failed = 0;
    var skipped = 0;
    var cancelled = false;

    final totalUnits = progressTotal ?? job.rowIndexes.length;
    var completedUnits = progressOffset;

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

    final command = DocxExportCommand(
      templateBytes: templateBytes,
      destinationFolder: job.destinationFolder,
      filenamePattern: job.filenamePattern,
      rowIndexes: job.rowIndexes,
      placeholders: placeholders,
      resolveRow: resolveRow,
      headers: headers,
      templateBaseName: job.templateBaseName,
      manualFilenames: job.filenameMode == FilenameMode.manual
          ? job.manualFilenames
          : null,
    );
    _active = command;
    final partial = await command.execute(
      onProgress: (event) {
        completedUnits = progressOffset + event.current;
        emit(event.label ?? 'Generando DOCX…');
      },
    );
    written.addAll(partial.writtenFiles);
    exported += partial.exportedCount;
    failed += partial.failedCount;
    skipped += partial.skippedCount;
    errors.addAll(partial.errors);
    cancelled = partial.cancelled;
    completedUnits = progressOffset + job.rowIndexes.length;

    String? zipPath;
    if (writeZip && job.createZip && written.isNotEmpty) {
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
