import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_mode.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/routing/workbench/workbench_tab.dart';
import 'package:forkumentos/routing/workbench/workbench_tab_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

final class WorkbenchStatusBar extends ConsumerWidget {
  const WorkbenchStatusBar({super.key});

  static const double height = 28;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(activeProjectProvider).valueOrNull;
    final tab = ref.watch(workbenchTabProvider);
    final exportReady = ref.watch(exportReadinessProvider);
    final workflowMode = ref.watch(mappingWorkflowProvider).mode;

    final statusText = _resolveStatusText(
      project: project,
      tab: tab,
      workflowMode: workflowMode,
      exportReady: exportReady,
    );

    return SizedBox(
      height: height,
      child: ColoredBox(
        color: AppColors.backgroundSecondary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.foregroundMuted),
            ),
          ),
        ),
      ),
    );
  }
}

String _resolveStatusText({
  required Project? project,
  required WorkbenchTab tab,
  required MappingWorkflowMode workflowMode,
  required bool exportReady,
}) {
  if (project == null) {
    return 'Sin proyecto activo';
  }

  final dirtySuffix = project.isDirty ? ' · Sin guardar' : '';
  final tabLabel = tab.label;

  if (tab == WorkbenchTab.review ||
      workflowMode == MappingWorkflowMode.review) {
    final readiness = exportReady ? 'lista' : 'bloqueada';
    return '${project.name} · $tabLabel · Exportación: $readiness'
        '$dirtySuffix';
  }

  return '${project.name} · $tabLabel$dirtySuffix';
}
