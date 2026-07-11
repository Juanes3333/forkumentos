import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';
import 'package:forkumentos/routing/app_phase_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

/// After a successful [ActiveProjectNotifier.loadProject], record recent and
/// enter workbench when the .fork already has both embedded resources.
Future<void> afterSuccessfulProjectLoad(WidgetRef ref) async {
  final state = ref.read(activeProjectProvider);
  final project = state.valueOrNull;
  if (state.hasError || project == null) {
    return;
  }

  final filePath = project.filePath;
  if (filePath != null && filePath.isNotEmpty) {
    await ref
        .read(recentProjectsProvider.notifier)
        .record(filePath: filePath, name: project.name);
  }

  final templatePath = project.embeddedTemplatePath;
  final datasourcePath = project.embeddedDatasourcePath;
  final hasTemplate = templatePath != null && templatePath.isNotEmpty;
  final hasDatasource = datasourcePath != null && datasourcePath.isNotEmpty;
  if (hasTemplate && hasDatasource) {
    ref.read(workbenchEnteredProvider.notifier).enterWorkbench();
  }
}
