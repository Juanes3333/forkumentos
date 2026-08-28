import 'package:flutter/material.dart';

enum OpenProjectChoice { openHere, newWindow, cancel }

/// Asks what to do when the user opens a project while another is active.
Future<OpenProjectChoice> confirmOpenProject(BuildContext context) async {
  final choice = await showDialog<OpenProjectChoice>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Abrir otro proyecto'),
        content: const Text(
          'Ya hay un proyecto abierto. ¿Dónde quieres abrir el nuevo?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(OpenProjectChoice.cancel),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(OpenProjectChoice.newWindow),
            child: const Text('Abrir en nueva ventana'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(OpenProjectChoice.openHere),
            child: const Text('Abrir aquí'),
          ),
        ],
      );
    },
  );

  return choice ?? OpenProjectChoice.cancel;
}
