import 'package:flutter/material.dart';
import 'package:forkumentos/core/open_in_explorer.dart';
import 'package:forkumentos/features/export/domain/export_result.dart';

/// Summary after an export session completes or is cancelled.
final class ExportSummaryDialog extends StatelessWidget {
  const ExportSummaryDialog({required this.result, super.key});

  final ExportResult result;

  static Future<void> show(BuildContext context, ExportResult result) {
    return showDialog<void>(
      context: context,
      builder: (context) => ExportSummaryDialog(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = result.cancelled
        ? 'Exportación cancelada'
        : 'Exportación completada';

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Exportados: ${result.exportedCount}'),
            Text('Fallidos: ${result.failedCount}'),
            Text('Omitidos: ${result.skippedCount}'),
            if (result.errors.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('Errores', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(result.errors.join('\n')),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => openFolderInExplorer(result.destinationFolder),
          child: const Text('Abrir carpeta'),
        ),
        if (result.zipPath != null)
          TextButton(
            onPressed: () => showFileInExplorer(result.zipPath!),
            child: const Text('Abrir ZIP'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
