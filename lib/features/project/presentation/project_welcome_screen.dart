import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/project/domain/recent_project.dart';
import 'package:forkumentos/features/project/presentation/create_project_dialog.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

final class ProjectWelcomeScreen extends ConsumerWidget {
  const ProjectWelcomeScreen({super.key, this.onOpenSettings});

  /// Opened by routing (Landing). Keeps settings UI out of this feature.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProjectState = ref.watch(activeProjectProvider);
    final errorMessage = _resolveErrorMessage(activeProjectState.error);
    final isLoading = activeProjectState.isLoading;
    final recentProjectsState = ref.watch(recentProjectsProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Inicia un proyecto',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (onOpenSettings != null)
                      IconButton(
                        tooltip: 'Configuración',
                        onPressed: isLoading ? null : onOpenSettings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Crea un nuevo proyecto o abre un archivo existente '
                  'para continuar.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (isLoading) ...<Widget>[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 12),
                ],
                if (errorMessage != null) ...<Widget>[
                  _ErrorMessage(
                    message: errorMessage,
                    onDismiss: () {
                      ref.read(activeProjectProvider.notifier).dismissError();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => _handleCreateProject(context, ref),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Crear proyecto'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => _handleOpenProject(context, ref),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Abrir proyecto'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Proyectos recientes',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: _RecentProjectsList(
                    entries:
                        recentProjectsState.valueOrNull ??
                        const <RecentProject>[],
                    isBusy: isLoading,
                    onSelect: (entry) => _handleOpenRecentProject(ref, entry),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreateProject(BuildContext context, WidgetRef ref) async {
    final projectName = await showCreateProjectDialog(context, ref);
    if (projectName == null) {
      return;
    }

    await ref
        .read(activeProjectProvider.notifier)
        .createProject(name: projectName);
  }

  Future<void> _handleOpenProject(BuildContext context, WidgetRef ref) async {
    final selected = await FilePicker.platform.pickFiles(
      dialogTitle: 'Abrir proyecto',
      type: FileType.custom,
      allowedExtensions: const <String>['fork'],
    );
    final filePath = selected?.files.single.path;
    if (filePath == null) {
      return;
    }

    if (!_isProjectFilePath(filePath)) {
      if (!context.mounted) {
        return;
      }
      await _showUnsupportedFileDialog(context);
      return;
    }

    await ref
        .read(activeProjectProvider.notifier)
        .loadProject(filePath: filePath);
    await _recordIfLoaded(ref);
  }

  Future<void> _handleOpenRecentProject(
    WidgetRef ref,
    RecentProject entry,
  ) async {
    await ref
        .read(activeProjectProvider.notifier)
        .loadProject(filePath: entry.filePath);
    await _recordIfLoaded(ref);
  }
}

Future<void> _recordIfLoaded(WidgetRef ref) async {
  final state = ref.read(activeProjectProvider);
  final project = state.valueOrNull;
  if (state.hasError || project == null || project.filePath == null) {
    return;
  }

  await ref
      .read(recentProjectsProvider.notifier)
      .record(filePath: project.filePath!, name: project.name);
}

Future<void> _showUnsupportedFileDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Archivo no compatible'),
        content: const Text('Selecciona un archivo con extensión .fork.'),
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

String? _resolveErrorMessage(Object? error) {
  if (error == null) {
    return null;
  }

  if (error is ProjectLifecycleException) {
    return error.message;
  }

  return 'Ocurrió un error al procesar el proyecto.';
}

bool _isProjectFilePath(String filePath) {
  return filePath.toLowerCase().endsWith(projectFileExtension);
}

final class _RecentProjectsList extends StatelessWidget {
  const _RecentProjectsList({
    required this.entries,
    required this.isBusy,
    required this.onSelect,
  });

  final List<RecentProject> entries;
  final bool isBusy;
  final ValueChanged<RecentProject> onSelect;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(
        'Sin proyectos recientes todavía.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        final entry = entries[index];
        return _RecentProjectTile(
          entry: entry,
          onTap: isBusy ? null : () => onSelect(entry),
        );
      },
    );
  }
}

final class _RecentProjectTile extends StatelessWidget {
  const _RecentProjectTile({required this.entry, required this.onTap});

  final RecentProject entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(entry.name),
      subtitle: Text(
        entry.filePath,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: onTap,
    );
  }
}

final class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(4),
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
