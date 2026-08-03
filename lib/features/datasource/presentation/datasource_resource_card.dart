import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/shared/import/dropped_file_kind.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/widgets/dropzone_surface.dart';

const _datasourceExtensions = <String>['csv', 'xlsx'];

final class DatasourceResourceCard extends ConsumerWidget {
  const DatasourceResourceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datasourceState = ref.watch(activeDatasourceProvider);
    final datasource = datasourceState.valueOrNull;
    final isLoading = datasourceState.isLoading;
    final errorMessage = _resolveErrorMessage(datasourceState.error);

    // Empty state skips the Card chrome entirely so the dropzone's own
    // border is the only box on screen — see TemplateResourceCard for why.
    if (datasource == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Fuente de datos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
            icon: Icons.table_chart_outlined,
            message:
                'Todavía no importaste un archivo CSV o XLSX. '
                'Arrastra un archivo a la ventana o haz clic para '
                'seleccionar.',
            actionLabel: 'Importar datos',
            actionIcon: Icons.table_chart_outlined,
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
            Text(
              'Fuente de datos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
              datasource: datasource,
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
    dialogTitle: 'Seleccionar fuente de datos',
    type: FileType.custom,
    allowedExtensions: _datasourceExtensions,
  );
  final filePath = selected?.files.single.path;
  if (filePath == null) {
    return;
  }
  if (!isDatasourcePath(filePath)) {
    return;
  }

  await ref
      .read(activeDatasourceProvider.notifier)
      .importDatasource(filePath: filePath);
  _syncEmbeddedDatasourcePath(ref);
}

void _syncEmbeddedDatasourcePath(WidgetRef ref) {
  final path = ref.read(activeDatasourceProvider).valueOrNull?.sourcePath;
  if (path == null) {
    return;
  }
  ref
      .read(activeProjectProvider.notifier)
      .setEmbeddedArtifactPaths(datasourcePath: path);
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

final class _LoadedState extends StatelessWidget {
  const _LoadedState({
    required this.datasource,
    required this.isLoading,
    required this.onReplace,
  });

  final Datasource datasource;
  final bool isLoading;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(datasource.fileName, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 4),
        Text(
          '${datasource.rowCount} filas · ${datasource.sourcePath}',
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
