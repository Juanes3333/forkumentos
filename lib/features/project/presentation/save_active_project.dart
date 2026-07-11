import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/project/presentation/confirm_overwrite_project_dialog.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';

export 'package:forkumentos/features/project/domain/project_repository.dart'
    show projectFileExtension;

/// Persists the active project. Uses the default workspace path when the
/// project has no filePath yet (no picker). Returns `false` on cancel/failure.
Future<bool> saveActiveProject(
  BuildContext context,
  WidgetRef ref,
  Project project,
) async {
  final notifier = ref.read(activeProjectProvider.notifier);

  if (project.filePath != null) {
    await notifier.saveProject(
      templateSourcePath: project.embeddedTemplatePath,
      datasourceSourcePath: project.embeddedDatasourcePath,
    );
    await recordSavedProject(ref);
    return !ref.read(activeProjectProvider).hasError;
  }

  final paths = ref.read(workspacePathsProvider);
  if (paths != null) {
    final defaultPath = paths.defaultProjectFile(project.name);
    // ignore: avoid_slow_async_io
    if (await File(defaultPath).exists()) {
      if (!context.mounted) {
        return false;
      }
      final overwrite = await confirmOverwriteProject(
        context,
        filePath: defaultPath,
      );
      if (!overwrite) {
        return false;
      }
    }

    await notifier.saveProject(
      filePath: defaultPath,
      templateSourcePath: project.embeddedTemplatePath,
      datasourceSourcePath: project.embeddedDatasourcePath,
    );
    await recordSavedProject(ref);
    return !ref.read(activeProjectProvider).hasError;
  }

  return saveActiveProjectAs(ref, project);
}

/// Always prompts for a destination path (Save As).
Future<bool> saveActiveProjectAs(WidgetRef ref, Project project) async {
  final rawPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar proyecto como',
    fileName: '${project.name}$projectFileExtension',
    type: FileType.custom,
    allowedExtensions: const <String>['fork'],
  );
  if (rawPath == null) {
    return false;
  }

  await ref
      .read(activeProjectProvider.notifier)
      .saveProject(
        filePath: normalizeProjectFilePath(rawPath),
        templateSourcePath: project.embeddedTemplatePath,
        datasourceSourcePath: project.embeddedDatasourcePath,
      );
  await recordSavedProject(ref);
  return !ref.read(activeProjectProvider).hasError;
}

Future<void> recordSavedProject(WidgetRef ref) async {
  final state = ref.read(activeProjectProvider);
  final savedProject = state.valueOrNull;
  if (state.hasError || savedProject == null || savedProject.filePath == null) {
    return;
  }

  await ref
      .read(recentProjectsProvider.notifier)
      .record(filePath: savedProject.filePath!, name: savedProject.name);
}

String normalizeProjectFilePath(String filePath) {
  if (filePath.toLowerCase().endsWith(projectFileExtension)) {
    return filePath;
  }

  return '$filePath$projectFileExtension';
}
