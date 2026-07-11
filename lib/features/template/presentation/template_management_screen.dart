import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/template/domain/template.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/shared/import/dropped_file_kind.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:intl/intl.dart';

const _templateExtensions = <String>['docx', 'pdf'];

final class TemplateManagementScreen extends ConsumerWidget {
  const TemplateManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProjectState = ref.watch(activeProjectProvider);
    final activeProject = activeProjectState.valueOrNull;

    if (activeProject == null) {
      if (activeProjectState.isLoading) {
        return const _CenteredStatus(
          title: 'Cargando proyecto...',
          showProgress: true,
        );
      }

      return const _CenteredStatus(
        title: 'No hay un proyecto activo.',
        description: 'Regresa a la vista de proyecto para abrir o crear uno.',
      );
    }

    final templateState = ref.watch(activeTemplateProvider);
    final notifier = ref.read(activeTemplateProvider.notifier);
    final template = templateState.valueOrNull;
    final errorMessage = _resolveErrorMessage(templateState.error);
    final isLoading = templateState.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (isLoading) const LinearProgressIndicator(minHeight: 2),
        if (errorMessage != null)
          _InlineError(message: errorMessage, onDismiss: notifier.dismissError),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: template == null
                    ? _TemplateEmptyState(
                        isLoading: isLoading,
                        onImport: () => _pickAndImportTemplate(ref),
                      )
                    : _TemplateDetailsState(
                        template: template,
                        isLoading: isLoading,
                        onReplace: () => _pickAndImportTemplate(ref),
                        onRemove: notifier.removeTemplate,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _pickAndImportTemplate(WidgetRef ref) async {
  final selected = await FilePicker.platform.pickFiles(
    dialogTitle: 'Seleccionar plantilla DOCX o PDF',
    type: FileType.custom,
    allowedExtensions: _templateExtensions,
  );
  final filePath = selected?.files.single.path;
  if (filePath == null || !isTemplatePath(filePath)) {
    return;
  }

  await ref
      .read(activeTemplateProvider.notifier)
      .importTemplate(filePath: filePath);
  final path = ref.read(activeTemplateProvider).valueOrNull?.sourcePath;
  if (path != null) {
    ref
        .read(activeProjectProvider.notifier)
        .setEmbeddedArtifactPaths(templatePath: path);
  }
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

String _formatFileSize(int bytes) {
  const units = <String>['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final pattern = unitIndex == 0 ? '#,##0' : '#,##0.0';
  final formatter = NumberFormat(pattern, 'es');
  return '${formatter.format(value)} ${units[unitIndex]}';
}

String _formatImportedAt(DateTime importedAt) {
  final formatter = DateFormat('dd/MM/yyyy HH:mm');
  return formatter.format(importedAt.toLocal());
}

final class _TemplateEmptyState extends StatelessWidget {
  const _TemplateEmptyState({required this.isLoading, required this.onImport});

  final bool isLoading;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Plantilla', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'Todavía no importaste una plantilla DOCX o PDF para este proyecto.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: isLoading ? null : onImport,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Importar plantilla'),
        ),
      ],
    );
  }
}

final class _TemplateDetailsState extends StatelessWidget {
  const _TemplateDetailsState({
    required this.template,
    required this.isLoading,
    required this.onReplace,
    required this.onRemove,
  });

  final Template template;
  final bool isLoading;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final metadataRows = <Widget>[
      _MetadataRow(label: 'Archivo', value: template.fileName),
      _MetadataRow(
        label: 'Tamaño',
        value: _formatFileSize(template.fileSizeBytes),
      ),
      _MetadataRow(
        label: 'Importada',
        value: _formatImportedAt(template.importedAt),
      ),
      _MetadataRow(
        label: 'Ruta',
        valueWidget: SelectableText(
          template.sourcePath,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ];

    final title = template.title;
    if (title != null) {
      metadataRows.add(_MetadataRow(label: 'Título', value: title));
    }

    final author = template.author;
    if (author != null) {
      metadataRows.add(_MetadataRow(label: 'Autor', value: author));
    }

    final pageCount = template.pageCount;
    if (pageCount != null) {
      metadataRows.add(
        _MetadataRow(label: 'Páginas', value: pageCount.toString()),
      );
    }

    final wordCount = template.wordCount;
    if (wordCount != null) {
      metadataRows.add(
        _MetadataRow(label: 'Palabras', value: wordCount.toString()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Plantilla activa', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...metadataRows,
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: isLoading ? null : onReplace,
              icon: const Icon(Icons.sync_outlined),
              label: const Text('Reemplazar plantilla'),
            ),
            OutlinedButton.icon(
              onPressed: isLoading ? null : onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Quitar plantilla'),
            ),
          ],
        ),
      ],
    );
  }
}

final class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, this.value, this.valueWidget})
    : assert(
        value != null || valueWidget != null,
        'MetadataRow requiere value o valueWidget.',
      );

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child:
                valueWidget ??
                Text(value!, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

final class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(onPressed: onDismiss, child: const Text('Cerrar')),
          ],
        ),
      ),
    );
  }
}

final class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({
    required this.title,
    this.description,
    this.showProgress = false,
  });

  final String title;
  final String? description;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (description != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (showProgress) ...<Widget>[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
