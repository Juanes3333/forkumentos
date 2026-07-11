import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

const projectFileExtension = '.forkumentos.json';

/// Persists the active project. Returns `false` if the user cancels Save As
/// or the save fails.
Future<bool> saveActiveProject(WidgetRef ref, Project project) async {
  final notifier = ref.read(activeProjectProvider.notifier);
  if (project.filePath != null) {
    await notifier.saveProject();
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
    allowedExtensions: const <String>['json'],
  );
  if (rawPath == null) {
    return false;
  }

  await ref
      .read(activeProjectProvider.notifier)
      .saveProject(filePath: normalizeProjectFilePath(rawPath));
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
