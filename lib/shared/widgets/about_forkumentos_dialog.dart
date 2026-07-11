import 'package:flutter/material.dart';
import 'package:forkumentos/shared/widgets/forkumentos_logo.dart';

/// App version shown in About; keep in sync with pubspec `version`.
const String forkumentosVersion = '1.0.0';

const String _forkumentosAuthor = 'Juan Restrepo';
const String _forkumentosWebsite = 'https://github.com/Juanes3333/forkumentos';
const String _forkumentosLicense = 'MIT';

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
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return AlertDialog(
      title: const Text('Acerca de'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ForkumentosLogo(height: 72),
            const SizedBox(height: 16),
            Text('Forkumentos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Versión $forkumentosVersion', style: muted),
            const SizedBox(height: 12),
            Text('Licencia: $_forkumentosLicense', style: muted),
            const SizedBox(height: 4),
            Text('Autor: $_forkumentosAuthor', style: muted),
            const SizedBox(height: 4),
            Text('Sitio web: $_forkumentosWebsite', style: muted),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Forkumentos',
                    applicationVersion: forkumentosVersion,
                    applicationLegalese:
                        'Copyright (c) 2026 $_forkumentosAuthor\n'
                        'Licencia $_forkumentosLicense',
                    applicationIcon: const Padding(
                      padding: EdgeInsets.all(8),
                      child: ForkumentosLogo(),
                    ),
                  );
                },
                child: const Text('Licencias de terceros'),
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
