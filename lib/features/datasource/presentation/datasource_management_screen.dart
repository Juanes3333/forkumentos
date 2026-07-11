import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:intl/intl.dart';

const _csvExtension = 'csv';
const _xlsxExtension = 'xlsx';
const _previewNoticeText =
    'Esta vista previa representa solo el primer registro. '
    'Todas las filas se usarán durante la exportación.';

final class DatasourceManagementScreen extends ConsumerWidget {
  const DatasourceManagementScreen({super.key});

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

    final datasourceState = ref.watch(activeDatasourceProvider);
    final notifier = ref.read(activeDatasourceProvider.notifier);
    final datasource = datasourceState.valueOrNull;
    final errorMessage = _resolveErrorMessage(datasourceState.error);
    final isLoading = datasourceState.isLoading;

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
                child: datasource == null
                    ? _DatasourceEmptyState(
                        isLoading: isLoading,
                        onImport: () => _pickAndImportDatasource(ref),
                      )
                    : _DatasourceDetailsState(
                        datasource: datasource,
                        isLoading: isLoading,
                        onReplace: () => _pickAndImportDatasource(ref),
                        onRemove: notifier.removeDatasource,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _pickAndImportDatasource(WidgetRef ref) async {
  final selected = await FilePicker.platform.pickFiles(
    dialogTitle: 'Seleccionar fuente de datos',
    type: FileType.custom,
    allowedExtensions: const <String>[_csvExtension, _xlsxExtension],
  );
  final filePath = selected?.files.single.path;
  if (filePath == null) {
    return;
  }

  await ref
      .read(activeDatasourceProvider.notifier)
      .importDatasource(filePath: filePath);
  final path = ref.read(activeDatasourceProvider).valueOrNull?.sourcePath;
  if (path != null) {
    ref
        .read(activeProjectProvider.notifier)
        .setEmbeddedArtifactPaths(datasourcePath: path);
  }
}

String? _resolveErrorMessage(Object? error) {
  if (error == null) {
    return null;
  }

  if (error is DatasourceLifecycleException) {
    return error.message;
  }

  return 'Ocurrió un error al gestionar la fuente de datos.';
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

String _formatLabel(DatasourceFormat format) {
  switch (format) {
    case DatasourceFormat.csv:
      return 'CSV';
    case DatasourceFormat.xlsx:
      return 'XLSX';
  }
}

final class _DatasourceEmptyState extends StatelessWidget {
  const _DatasourceEmptyState({
    required this.isLoading,
    required this.onImport,
  });

  final bool isLoading;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Fuente de datos', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'Todavía no importaste un archivo CSV o XLSX para este proyecto.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Tooltip(
          message: 'Selecciona un archivo CSV o XLSX para este proyecto',
          child: FilledButton.icon(
            onPressed: isLoading ? null : onImport,
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Importar datos'),
          ),
        ),
      ],
    );
  }
}

final class _DatasourceDetailsState extends StatelessWidget {
  const _DatasourceDetailsState({
    required this.datasource,
    required this.isLoading,
    required this.onReplace,
    required this.onRemove,
  });

  final Datasource datasource;
  final bool isLoading;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final metadataRows = <Widget>[
      _MetadataRow(label: 'Archivo', value: datasource.fileName),
      _MetadataRow(
        label: 'Tamaño',
        value: _formatFileSize(datasource.fileSizeBytes),
      ),
      _MetadataRow(
        label: 'Importada',
        value: _formatImportedAt(datasource.importedAt),
      ),
      _MetadataRow(label: 'Formato', value: _formatLabel(datasource.format)),
      _MetadataRow(label: 'Filas', value: datasource.rowCount.toString()),
      _MetadataRow(
        label: 'Ruta',
        valueWidget: SelectableText(
          datasource.sourcePath,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ];

    final emptyColumns = datasource.emptyColumnIndexes
        .where((int index) => index >= 0 && index < datasource.headers.length)
        .map((int index) => datasource.headers[index])
        .toList(growable: false);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Fuente de datos activa',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...metadataRows,
          const SizedBox(height: 16),
          Text('Encabezados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Material(
            type: MaterialType.transparency,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final header in datasource.headers)
                  Chip(label: Text(header.isEmpty ? '(vacío)' : header)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Vista previa (primer registro)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < datasource.headers.length; index++)
            _MetadataRow(
              label: datasource.headers[index].isEmpty
                  ? '(vacío)'
                  : datasource.headers[index],
              value: datasource.previewRow[index] ?? '(vacío)',
            ),
          const SizedBox(height: 12),
          Text(
            _previewNoticeText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (emptyColumns.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _InlineInfo(
              message:
                  'Columnas completamente vacías detectadas: '
                  '${emptyColumns.join(', ')}.',
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Tooltip(
                message: 'Selecciona otro archivo para sustituir esta fuente',
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onReplace,
                  icon: const Icon(Icons.sync_outlined),
                  label: const Text('Reemplazar datos'),
                ),
              ),
              Tooltip(
                message: 'Quita la fuente de datos activa de este proyecto',
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Quitar datos'),
                ),
              ),
            ],
          ),
        ],
      ),
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

final class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline,
              size: 18,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
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
