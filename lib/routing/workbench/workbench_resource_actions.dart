import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Copies a resource file to a user-chosen destination via Save dialog.
Future<void> exportResourceByCopy({
  required BuildContext context,
  required String sourcePath,
  required String dialogTitle,
  required String suggestedFileName,
  required List<String> allowedExtensions,
}) async {
  final destination = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: suggestedFileName,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
  );
  if (destination == null) {
    return;
  }

  try {
    final normalizedDestination = _ensureExtension(
      destination,
      p.extension(suggestedFileName).replaceFirst('.', ''),
    );
    await File(sourcePath).copy(normalizedDestination);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Archivo exportado: $normalizedDestination')),
    );
  } on Object catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo exportar el archivo: $error')),
    );
  }
}

String _ensureExtension(String filePath, String extension) {
  if (extension.isEmpty) {
    return filePath;
  }
  final lower = filePath.toLowerCase();
  final suffix = '.${extension.toLowerCase()}';
  if (lower.endsWith(suffix)) {
    return filePath;
  }
  return '$filePath$suffix';
}
