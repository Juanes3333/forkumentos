import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:path/path.dart' as p;

const _csvExtension = 'csv';
const _xlsxExtension = 'xlsx';

final class DatasourceResourceCard extends ConsumerStatefulWidget {
  const DatasourceResourceCard({super.key});

  @override
  ConsumerState<DatasourceResourceCard> createState() =>
      _DatasourceResourceCardState();
}

final class _DatasourceResourceCardState
    extends ConsumerState<DatasourceResourceCard> {
  var _dragging = false;

  @override
  Widget build(BuildContext context) {
    final datasourceState = ref.watch(activeDatasourceProvider);
    final datasource = datasourceState.valueOrNull;
    final isLoading = datasourceState.isLoading;
    final errorMessage = _resolveErrorMessage(datasourceState.error);

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) async {
        setState(() => _dragging = false);
        final candidates = detail.files
            .map((file) => file.path)
            .where(_isDatasourceFile)
            .toList();
        if (candidates.isEmpty) {
          return;
        }
        await ref
            .read(activeDatasourceProvider.notifier)
            .importDatasource(filePath: candidates.first);
        _syncEmbeddedDatasourcePath(ref);
      },
      child: Card(
        color: _dragging
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
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
              if (datasource == null)
                _EmptyState(
                  isLoading: isLoading,
                  onImport: () => _pickAndImport(ref),
                )
              else
                _LoadedState(
                  datasource: datasource,
                  isLoading: isLoading,
                  onReplace: () => _pickAndImport(ref),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isDatasourceFile(String path) {
  final ext = p.extension(path).toLowerCase();
  return ext == '.$_csvExtension' || ext == '.$_xlsxExtension';
}

Future<void> _pickAndImport(WidgetRef ref) async {
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

final class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isLoading, required this.onImport});

  final bool isLoading;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Todavía no importaste un archivo CSV o XLSX. '
          'Arrastra un archivo o haz clic para seleccionar.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isLoading ? null : onImport,
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('Importar datos'),
        ),
      ],
    );
  }
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
