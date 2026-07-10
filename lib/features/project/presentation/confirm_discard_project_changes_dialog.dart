import 'package:flutter/material.dart';

Future<bool> confirmDiscardProjectChanges(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Proyecto sin guardar'),
        content: const Text(
          'El proyecto actual no está guardado. '
          'Esta acción descartará sus datos no guardados.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}
