import 'dart:io';
import 'dart:typed_data';

import 'package:forkumentos/features/export/data/export_zip_writer.dart';
import 'package:forkumentos/features/export/domain/export_job.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:forkumentos/features/export/domain/export_progress.dart';
import 'package:forkumentos/features/export/domain/export_result.dart';
import 'package:forkumentos/routing/workbench/export_launcher.dart';
import 'package:path/path.dart' as p;

/// Una plantilla lista para exportar: su nombre (para la subcarpeta y el
/// patrón de nombres), el DOCX y su mapeo ya traducido.
typedef TemplateExportInput = ({
  String name,
  Uint8List bytes,
  List<ExportPlaceholder> placeholders,
});

/// Exporta cada fila con cada plantilla de [templates]. Ejecuta el comando de
/// exportación existente una vez por plantilla, sin modificarlo:
///
/// - cada plantilla escribe en su **propia subcarpeta** de
///   `job.destinationFolder` (así dos plantillas nunca pisan el mismo
///   archivo, aunque el patrón de nombres sea solo un campo);
/// - el avance cuenta `filas × plantillas`;
/// - con `job.createZip` se arma **un** ZIP con una carpeta por plantilla;
/// - si se cancela, se borra todo lo que esta exportación ya había escrito
///   (no queda un paquete a medias).
Future<ExportResult> runTemplatesExport({
  required ExportSession session,
  required ExportJob job,
  required List<TemplateExportInput> templates,
  required List<String> headers,
  required Future<List<String?>> Function(int rowIndex) resolveRow,
  required void Function(ExportProgress progress) onProgress,
}) async {
  final started = DateTime.now();
  final rows = job.rowIndexes.length;
  final total = rows * templates.length;
  final written = <String>[];
  final errors = <String>[];
  final folders = <String>[];
  final usedNames = <String>{};
  var failed = 0;
  var skipped = 0;
  var exported = 0;

  for (var index = 0; index < templates.length; index++) {
    final template = templates[index];
    if (session.cancelRequested) {
      skipped += rows;
      continue;
    }
    final folderName = _uniqueFolderName(template.name, usedNames);
    final folder = p.join(job.destinationFolder, folderName);
    await Directory(folder).create(recursive: true);
    folders.add(folder);

    final result = await session.run(
      job: job.copyWith(
        destinationFolder: folder,
        createZip: false,
        templateBaseName: template.name,
      ),
      templateBytes: template.bytes,
      placeholders: template.placeholders,
      headers: headers,
      resolveRow: resolveRow,
      onProgress: onProgress,
      progressOffset: index * rows,
      progressTotal: total,
      writeZip: false,
    );
    written.addAll(result.writtenFiles);
    errors.addAll(result.errors);
    exported += result.exportedCount;
    failed += result.failedCount;
    skipped += result.skippedCount;
  }

  if (session.cancelRequested) {
    for (final path in written) {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    for (final folder in folders) {
      final directory = Directory(folder);
      if (directory.existsSync() && directory.listSync().isEmpty) {
        directory.deleteSync();
      }
    }
    onProgress(
      ExportProgress(
        current: 0,
        total: total,
        label: 'Exportación cancelada',
        elapsed: DateTime.now().difference(started),
      ),
    );
    return ExportResult(
      exportedCount: 0,
      failedCount: failed,
      skippedCount: total,
      destinationFolder: job.destinationFolder,
      writtenFiles: const <String>[],
      cancelled: true,
      errors: errors,
    );
  }

  String? zipPath;
  if (job.createZip && written.isNotEmpty) {
    onProgress(
      ExportProgress(
        current: total,
        total: total,
        label: 'Creando ZIP…',
        elapsed: DateTime.now().difference(started),
      ),
    );
    zipPath = await const ExportZipWriter().writeZip(
      zipPath: p.join(
        job.destinationFolder,
        'export_${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
      filePaths: written,
      entryNames: <String, String>{
        for (final path in written)
          path: p.posix.join(p.basename(p.dirname(path)), p.basename(path)),
      },
    );
  }

  onProgress(
    ExportProgress(
      current: total,
      total: total,
      label: 'Exportación completada',
      elapsed: DateTime.now().difference(started),
    ),
  );
  return ExportResult(
    exportedCount: exported,
    failedCount: failed,
    skippedCount: skipped,
    destinationFolder: job.destinationFolder,
    writtenFiles: written,
    zipPath: zipPath,
    errors: errors,
  );
}

/// Nombre de subcarpeta válido en Windows y distinto de los ya usados.
String _uniqueFolderName(String name, Set<String> used) {
  final base = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
  final safe = base.isEmpty ? 'Plantilla' : base;
  var candidate = safe;
  var counter = 2;
  while (!used.add(candidate.toLowerCase())) {
    candidate = '$safe ($counter)';
    counter++;
  }
  return candidate;
}
