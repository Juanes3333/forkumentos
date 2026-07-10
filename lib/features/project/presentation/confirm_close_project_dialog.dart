import 'package:flutter/material.dart';

enum CloseProjectChoice { saveAndClose, closeWithoutSaving, cancel }

Future<CloseProjectChoice> confirmCloseProject(BuildContext context) async {
  final choice = await showDialog<CloseProjectChoice>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Proyecto sin guardar'),
        content: const Text(
          'El proyecto actual tiene cambios sin guardar. '
          '¿Qué deseas hacer antes de cerrar?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(CloseProjectChoice.cancel),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(CloseProjectChoice.closeWithoutSaving),
            child: const Text('Cerrar sin guardar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(CloseProjectChoice.saveAndClose),
            child: const Text('Guardar y cerrar'),
          ),
        ],
      );
    },
  );

  return choice ?? CloseProjectChoice.cancel;
}
