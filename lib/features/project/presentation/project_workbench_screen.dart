import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/presentation/confirm_discard_project_changes_dialog.dart';
import 'package:forkumentos/features/project/presentation/project_toolbar.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

const _projectFileExtension = '.forkumentos.json';

final class ProjectWorkbenchScreen extends ConsumerWidget {
  const ProjectWorkbenchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProjectState = ref.watch(activeProjectProvider);
    final project = activeProjectState.valueOrNull;

    if (project == null) {
      if (activeProjectState.isLoading) {
        return const _CenteredStatus(
          title: 'Procesando proyecto...',
          showProgress: true,
        );
      }

      if (activeProjectState.hasError) {
        return _CenteredStatus(
          title: _resolveErrorMessage(activeProjectState.error),
          actionLabel: 'Cerrar',
          onAction: () {
            ref.read(activeProjectProvider.notifier).dismissError();
          },
        );
      }

      return const _CenteredStatus(title: 'No hay proyecto activo.');
    }

    final notifier = ref.read(activeProjectProvider.notifier);
    final errorMessage = activeProjectState.hasError
        ? _resolveErrorMessage(activeProjectState.error)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ProjectToolbar(
          project: project,
          onSave: () => _handleSave(context, ref, notifier, project),
          onSaveAs: project.filePath == null
              ? null
              : () => _handleSaveAs(context, ref, notifier, project),
          onOpen: () => _handleOpen(context, ref, notifier, project),
          onClose: () => _handleClose(context, notifier, project),
          isBusy: activeProjectState.isLoading,
        ),
        if (activeProjectState.isLoading)
          const LinearProgressIndicator(minHeight: 2),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Proyecto activo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nombre: ${project.name}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      project.isDirty
                          ? 'Estado: Sin guardar'
                          : 'Estado: Guardado',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'Ruta: ${project.filePath ?? 'Sin ruta asignada'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave(
    BuildContext context,
    WidgetRef ref,
    ActiveProjectNotifier notifier,
    Project project,
  ) async {
    if (project.filePath != null) {
      await notifier.saveProject();
      await _recordIfSaved(ref);
      return;
    }

    await _handleSaveAs(context, ref, notifier, project);
  }

  Future<void> _handleSaveAs(
    BuildContext context,
    WidgetRef ref,
    ActiveProjectNotifier notifier,
    Project project,
  ) async {
    final rawPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar proyecto',
      fileName: '${project.name}$_projectFileExtension',
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (rawPath == null) {
      return;
    }

    final normalizedPath = _normalizeProjectFilePath(rawPath);
    await notifier.saveProject(filePath: normalizedPath);
    await _recordIfSaved(ref);
  }

  Future<void> _handleOpen(
    BuildContext context,
    WidgetRef ref,
    ActiveProjectNotifier notifier,
    Project project,
  ) async {
    if (project.isDirty) {
      final shouldContinue = await confirmDiscardProjectChanges(context);
      if (!shouldContinue) {
        return;
      }
    }

    final selected = await FilePicker.platform.pickFiles(
      dialogTitle: 'Abrir proyecto',
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
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

    await notifier.loadProject(filePath: filePath);
    await _recordIfSaved(ref);
  }

  Future<void> _handleClose(
    BuildContext context,
    ActiveProjectNotifier notifier,
    Project project,
  ) async {
    if (project.isDirty) {
      final shouldContinue = await confirmDiscardProjectChanges(context);
      if (!shouldContinue) {
        return;
      }
    }

    await notifier.closeProject();
  }
}

Future<void> _recordIfSaved(WidgetRef ref) async {
  final state = ref.read(activeProjectProvider);
  final project = state.valueOrNull;
  if (state.hasError || project == null || project.filePath == null) {
    return;
  }

  await ref
      .read(recentProjectsProvider.notifier)
      .record(filePath: project.filePath!, name: project.name);
}

String _normalizeProjectFilePath(String filePath) {
  if (filePath.toLowerCase().endsWith(_projectFileExtension)) {
    return filePath;
  }

  return '$filePath$_projectFileExtension';
}

bool _isProjectFilePath(String filePath) {
  return filePath.toLowerCase().endsWith(_projectFileExtension);
}

String _resolveErrorMessage(Object? error) {
  if (error is ProjectLifecycleException) {
    return error.message;
  }

  return 'Ocurrió un error al procesar el proyecto.';
}

Future<void> _showUnsupportedFileDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Archivo no compatible'),
        content: const Text(
          'Selecciona un archivo con extensión .forkumentos.json.',
        ),
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
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (showProgress) ...<Widget>[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
