import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/presentation/confirm_close_project_dialog.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

const _appTitle = 'Forkumentos';
const _projectFileExtension = '.forkumentos.json';

final class ProjectWindowLifecycle extends ConsumerStatefulWidget {
  const ProjectWindowLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ProjectWindowLifecycle> createState() =>
      _ProjectWindowLifecycleState();
}

final class _ProjectWindowLifecycleState
    extends ConsumerState<ProjectWindowLifecycle> {
  String? _lastTitleSet;

  @override
  void initState() {
    super.initState();
    final windowService = ref.read(windowServiceProvider)
      ..addCloseListener(_handleCloseRequested);
    unawaited(windowService.setPreventClose(true));
    _syncWindowTitle(ref.read(activeProjectProvider).valueOrNull);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Project?>>(activeProjectProvider, (
      _,
      AsyncValue<Project?> next,
    ) {
      _syncWindowTitle(next.valueOrNull);
    });

    return widget.child;
  }

  void _syncWindowTitle(Project? project) {
    final title = _resolveTitle(project);
    if (title == _lastTitleSet) {
      return;
    }

    _lastTitleSet = title;
    unawaited(ref.read(windowServiceProvider).setTitle(title));
  }

  String _resolveTitle(Project? project) {
    if (project == null) {
      return _appTitle;
    }

    if (project.isDirty) {
      return '$_appTitle — ${project.name} *';
    }

    return '$_appTitle — ${project.name}';
  }

  Future<void> _handleCloseRequested() async {
    final project = ref.read(activeProjectProvider).valueOrNull;
    final windowService = ref.read(windowServiceProvider);

    if (project == null || !project.isDirty) {
      await windowService.destroy();
      return;
    }

    if (!mounted) {
      return;
    }

    final choice = await confirmCloseProject(context);
    switch (choice) {
      case CloseProjectChoice.cancel:
        return;
      case CloseProjectChoice.closeWithoutSaving:
        await windowService.destroy();
      case CloseProjectChoice.saveAndClose:
        final saved = await _saveProject(project);
        if (saved) {
          await windowService.destroy();
        }
    }
  }

  Future<bool> _saveProject(Project project) async {
    final notifier = ref.read(activeProjectProvider.notifier);
    if (project.filePath != null) {
      await notifier.saveProject();
      await _recordIfSaved();
      return !ref.read(activeProjectProvider).hasError;
    }

    final rawPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar proyecto',
      fileName: '${project.name}$_projectFileExtension',
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (rawPath == null) {
      return false;
    }

    await notifier.saveProject(filePath: _normalizeProjectFilePath(rawPath));
    await _recordIfSaved();
    return !ref.read(activeProjectProvider).hasError;
  }

  Future<void> _recordIfSaved() async {
    final state = ref.read(activeProjectProvider);
    final savedProject = state.valueOrNull;
    if (state.hasError ||
        savedProject == null ||
        savedProject.filePath == null) {
      return;
    }

    await ref
        .read(recentProjectsProvider.notifier)
        .record(filePath: savedProject.filePath!, name: savedProject.name);
  }
}

String _normalizeProjectFilePath(String filePath) {
  if (filePath.toLowerCase().endsWith(_projectFileExtension)) {
    return filePath;
  }

  return '$filePath$_projectFileExtension';
}
