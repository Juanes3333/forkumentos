import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/template/domain/template.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/shared/import/dropped_file_kind.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/widgets/dropzone_surface.dart';

const _templateExtensions = <String>['docx'];

final class TemplateResourceCard extends ConsumerWidget {
  const TemplateResourceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateState = ref.watch(activeTemplateProvider);
    final template = templateState.valueOrNull;
    final isLoading = templateState.isLoading;
    final errorMessage = _resolveErrorMessage(templateState.error);

    // Empty state skips the Card chrome entirely so the dropzone's own
    // border is the only box on screen — nesting it inside a second bordered
    // panel would read as a card-in-a-card and shrink the area available to
    // the thing this screen most wants the user to notice.
    if (template == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Plantilla', style: Theme.of(context).textTheme.titleMedium),
          if (isLoading) ...<Widget>[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (errorMessage != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropzoneSurface(
            icon: Icons.description_outlined,
            message:
                'Todavía no importaste una plantilla DOCX. '
                'Arrastra un archivo a la ventana o haz clic para '
                'seleccionar.',
            actionLabel: 'Importar plantilla',
            actionIcon: Icons.description_outlined,
            onImport: isLoading ? null : () => _pickAndImport(ref),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Plantilla', style: Theme.of(context).textTheme.titleMedium),
            if (isLoading) ...<Widget>[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _LoadedState(
              template: template,
              isLoading: isLoading,
              onReplace: () => _pickAndImport(ref),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pickAndImport(WidgetRef ref) async {
  final selected = await FilePicker.platform.pickFiles(
    dialogTitle: 'Seleccionar plantilla DOCX',
    type: FileType.custom,
    allowedExtensions: _templateExtensions,
  );
  final filePath = selected?.files.single.path;
  if (filePath == null) {
    return;
  }
  if (!isTemplatePath(filePath)) {
    return;
  }

  await ref
      .read(activeTemplateProvider.notifier)
      .importTemplate(filePath: filePath);
  _syncEmbeddedTemplatePath(ref);
}

void _syncEmbeddedTemplatePath(WidgetRef ref) {
  final path = ref.read(activeTemplateProvider).valueOrNull?.sourcePath;
  if (path == null) {
    return;
  }
  ref
      .read(activeProjectProvider.notifier)
      .setEmbeddedArtifactPaths(templatePath: path);
}

String? _resolveErrorMessage(Object? error) {
  if (error == null) {
    return null;
  }

  if (error is TemplateLifecycleException) {
    return error.message;
  }

  return 'Ocurrió un error al gestionar la plantilla.';
}

final class _LoadedState extends StatelessWidget {
  const _LoadedState({
    required this.template,
    required this.isLoading,
    required this.onReplace,
  });

  final Template template;
  final bool isLoading;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(template.fileName, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 4),
        Text(
          template.sourcePath,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isLoading ? null : onReplace,
          icon: const Icon(Icons.sync_outlined),
          label: const Text('Reemplazar'),
        ),
      ],
    );
  }
}
