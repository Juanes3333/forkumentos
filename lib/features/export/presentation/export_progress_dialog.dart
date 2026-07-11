import 'package:flutter/material.dart';
import 'package:forkumentos/features/export/domain/export_progress.dart';

/// Modal progress for a running export session.
final class ExportProgressDialog extends StatelessWidget {
  const ExportProgressDialog({
    required this.progress,
    required this.onCancel,
    super.key,
  });

  final ExportProgress progress;
  final VoidCallback onCancel;

  static Future<void> show(
    BuildContext context, {
    required ValueNotifier<ExportProgress> progressNotifier,
    required VoidCallback onCancel,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ValueListenableBuilder<ExportProgress>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            return ExportProgressDialog(progress: progress, onCancel: onCancel);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = progress.elapsed;
    final elapsedLabel =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:'
        '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

    return AlertDialog(
      title: const Text('Exportando'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(progress.label ?? 'Preparando…'),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.fraction),
            const SizedBox(height: 8),
            Text(
              '${progress.current} / ${progress.total}  ·  '
              '${progress.percent}%  ·  $elapsedLabel',
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: onCancel, child: const Text('Cancelar')),
      ],
    );
  }
}
