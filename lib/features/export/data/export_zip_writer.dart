import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Optionally packs already-written export files into a ZIP.
///
/// Originals stay on disk; the ZIP is an additional artifact.
final class ExportZipWriter {
  const ExportZipWriter();

  /// Creates [zipPath] containing [filePaths]. Returns the ZIP path.
  Future<String> writeZip({
    required String zipPath,
    required List<String> filePaths,
  }) async {
    final archive = Archive();
    for (final filePath in filePaths) {
      final file = File(filePath);
      if (!file.existsSync()) {
        continue;
      }
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(p.basename(filePath), bytes.length, bytes));
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw const FormatException('No se pudo crear el ZIP de exportación.');
    }

    await File(zipPath).writeAsBytes(encoded, flush: true);
    return zipPath;
  }
}
