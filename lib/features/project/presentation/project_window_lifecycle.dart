import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/window/window_service_providers.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/presentation/confirm_close_project_dialog.dart';
import 'package:forkumentos/features/project/presentation/save_active_project.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

const _appTitle = 'Forkumentos';

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
        final saved = await saveActiveProject(ref, project);
        if (saved) {
          await windowService.destroy();
        }
    }
  }
}
