import 'package:flutter/material.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';

/// Modal, unmissable error surface for a failed datasource import. The inline
/// error strip alone was too easy to miss when the panel was scrolled or the
/// import "looked like nothing happened" (Bug 2).
Future<void> showDatasourceImportErrorDialog(
  BuildContext context,
  Object? error,
) {
  final message = _resolveMessage(error);
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        icon: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          size: 40,
        ),
        title: const Text('Error al importar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message),
            if (error != null) ...<Widget>[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Ver más detalles'),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SelectableText(
                    error.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      );
    },
  );
}

String _resolveMessage(Object? error) {
  if (error is DatasourceLifecycleException) {
    return error.message;
  }
  return 'Ocurrió un error al importar la fuente de datos.';
}
