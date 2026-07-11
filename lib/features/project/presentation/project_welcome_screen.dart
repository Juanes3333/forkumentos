import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/launch/launch_arguments.dart';
import 'package:forkumentos/core/launch/spawn_app_instance.dart';
import 'package:forkumentos/core/open_in_explorer.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/project/domain/recent_project.dart';
import 'package:forkumentos/features/project/presentation/create_project_dialog.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';
import 'package:forkumentos/routing/after_project_load.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';
import 'package:forkumentos/shared/widgets/forkumentos_logo.dart';
import 'package:intl/intl.dart';

final class ProjectWelcomeScreen extends ConsumerStatefulWidget {
  const ProjectWelcomeScreen({super.key, this.onOpenSettings});

  /// Opened by routing (Landing). Keeps settings UI out of this feature.
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<ProjectWelcomeScreen> createState() =>
      _ProjectWelcomeScreenState();
}

final class _ProjectWelcomeScreenState
    extends ConsumerState<ProjectWelcomeScreen> {
  var _didAutoOpenRecent = false;

  @override
  Widget build(BuildContext context) {
    final activeProjectState = ref.watch(activeProjectProvider);
    final errorMessage = _resolveErrorMessage(activeProjectState.error);
    final isLoading = activeProjectState.isLoading;
    final recentProjectsState = ref.watch(recentProjectsProvider);
    final recentLimit = ref.watch(recentProjectsLimitProvider);
    final openRecentOnStartup = ref.watch(openRecentOnStartupProvider);
    final recentEntries =
        (recentProjectsState.valueOrNull ?? const <RecentProject>[])
            .take(recentLimit)
            .toList();

    _maybeAutoOpenRecent(
      openRecentOnStartup: openRecentOnStartup,
      recentReady: recentProjectsState.hasValue,
      entries: recentEntries,
      isLoading: isLoading,
    );

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
                const Center(child: ForkumentosLogo(height: 64)),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Forkumentos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Inicia un proyecto',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (widget.onOpenSettings != null)
                      IconButton(
                        tooltip: 'Configuración',
                        onPressed: isLoading ? null : widget.onOpenSettings,
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
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Proyectos recientes',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (recentEntries.isNotEmpty)
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => ref
                                  .read(recentProjectsProvider.notifier)
                                  .clear(),
                        child: const Text('Borrar historial'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: _RecentProjectsList(
                    entries: recentEntries,
                    isBusy: isLoading,
                    onSelect: (entry) => _handleOpenRecentProject(ref, entry),
                    onRemove: (entry) => ref
                        .read(recentProjectsProvider.notifier)
                        .remove(entry.filePath),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _maybeAutoOpenRecent({
    required bool openRecentOnStartup,
    required bool recentReady,
    required List<RecentProject> entries,
    required bool isLoading,
  }) {
    if (_didAutoOpenRecent ||
        !openRecentOnStartup ||
        !recentReady ||
        entries.isEmpty ||
        isLoading) {
      return;
    }

    // Let argv launch handling win over openRecentOnStartup.
    final underTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (!underTest) {
      final args = Platform.executableArguments;
      if (resolveLaunchProjectPath(args) != null || wantsNewProject(args)) {
        return;
      }
    }

    _didAutoOpenRecent = true;
    final entry = entries.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handleOpenRecentProject(ref, entry);
    });
  }

  Future<void> _handleCreateProject(BuildContext context, WidgetRef ref) async {
    if (ref.read(activeProjectProvider).valueOrNull != null) {
      await spawnAppInstance(newProject: true);
      return;
    }

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

    if (ref.read(activeProjectProvider).valueOrNull != null) {
      await spawnAppInstance(projectPath: filePath);
      return;
    }

    await ref
        .read(activeProjectProvider.notifier)
        .loadProject(filePath: filePath);
    await afterSuccessfulProjectLoad(ref);
  }

  Future<void> _handleOpenRecentProject(
    WidgetRef ref,
    RecentProject entry,
  ) async {
    // ignore: avoid_slow_async_io
    if (!await File(entry.filePath).exists()) {
      if (!mounted) {
        return;
      }
      final remove = await _showMissingRecentDialog(context, entry);
      if (remove ?? false) {
        await ref.read(recentProjectsProvider.notifier).remove(entry.filePath);
      }
      return;
    }

    if (ref.read(activeProjectProvider).valueOrNull != null) {
      await spawnAppInstance(projectPath: entry.filePath);
      return;
    }

    await ref
        .read(activeProjectProvider.notifier)
        .loadProject(filePath: entry.filePath);
    await afterSuccessfulProjectLoad(ref);
  }
}

Future<bool?> _showMissingRecentDialog(
  BuildContext context,
  RecentProject entry,
) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Proyecto no encontrado'),
        content: Text(
          'No se encontró el archivo:\n${entry.filePath}\n\n'
          '¿Quieres quitarlo de la lista de recientes?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar de la lista'),
          ),
        ],
      );
    },
  );
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

String _formatLastOpenedAt(DateTime lastOpenedAt) {
  return DateFormat('dd/MM/yyyy HH:mm').format(lastOpenedAt.toLocal());
}

final class _RecentProjectsList extends StatelessWidget {
  const _RecentProjectsList({
    required this.entries,
    required this.isBusy,
    required this.onSelect,
    required this.onRemove,
  });

  final List<RecentProject> entries;
  final bool isBusy;
  final ValueChanged<RecentProject> onSelect;
  final ValueChanged<RecentProject> onRemove;

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
          onRemove: isBusy ? null : () => onRemove(entry),
        );
      },
    );
  }
}

final class _RecentProjectTile extends StatelessWidget {
  const _RecentProjectTile({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  final RecentProject entry;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(entry.name),
      subtitle: Text(
        _formatLastOpenedAt(entry.lastOpenedAt),
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Más acciones',
        onSelected: (value) {
          if (value == 'show_in_explorer') {
            showFileInExplorer(entry.filePath);
          } else if (value == 'remove' && onRemove != null) {
            onRemove!();
          }
        },
        itemBuilder: (BuildContext context) {
          return <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'show_in_explorer',
              child: Text('Mostrar en el Explorador'),
            ),
            PopupMenuItem<String>(
              value: 'remove',
              enabled: onRemove != null,
              child: const Text('Quitar de la lista'),
            ),
          ];
        },
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
