import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/project/presentation/confirm_close_project_dialog.dart';
import 'package:forkumentos/features/project/presentation/save_active_project.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

/// Closes the active project and returns to Landing.
/// Returns `false` when the user cancels or save fails.
Future<bool> closeActiveProject(BuildContext context, WidgetRef ref) async {
  final project = ref.read(activeProjectProvider).valueOrNull;
  if (project == null) {
    return true;
  }

  if (!project.isDirty) {
    await ref.read(activeProjectProvider.notifier).closeProject();
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  final choice = await confirmCloseProject(context);
  switch (choice) {
    case CloseProjectChoice.cancel:
      return false;
    case CloseProjectChoice.closeWithoutSaving:
      await ref.read(activeProjectProvider.notifier).closeProject();
      return true;
    case CloseProjectChoice.saveAndClose:
      if (!context.mounted) {
        return false;
      }
      final saved = await saveActiveProject(context, ref, project);
      if (!saved) {
        return false;
      }
      await ref.read(activeProjectProvider.notifier).closeProject();
      return true;
  }
}
