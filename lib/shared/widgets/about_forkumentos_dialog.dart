import 'package:flutter/material.dart';
import 'package:forkumentos/shared/widgets/forkumentos_logo.dart';

/// App version shown in About; keep in sync with pubspec `version`.
const String forkumentosVersion = '1.0.0';

Future<void> showAboutForkumentosDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => const AboutForkumentosDialog(),
  );
}

final class AboutForkumentosDialog extends StatelessWidget {
  const AboutForkumentosDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Acerca de'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ForkumentosLogo(height: 72),
            const SizedBox(height: 16),
            Text('Forkumentos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Versión $forkumentosVersion',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
