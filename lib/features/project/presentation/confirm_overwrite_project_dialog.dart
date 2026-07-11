import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Asks whether to overwrite an existing project file.
/// Returns `false` on cancel.
Future<bool> confirmOverwriteProject(
  BuildContext context, {
  required String filePath,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Sobrescribir proyecto'),
        content: Text(
          'Ya existe un archivo llamado "${p.basename(filePath)}". '
          '¿Deseas reemplazarlo?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reemplazar'),
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}
