import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/project/presentation/project_welcome_screen.dart';
import 'package:forkumentos/features/project/presentation/project_window_lifecycle.dart';
import 'package:forkumentos/routing/workbench/workbench_inspector.dart';
import 'package:forkumentos/routing/workbench/workbench_ribbon.dart';
import 'package:forkumentos/routing/workbench/workbench_status_bar.dart';
import 'package:forkumentos/routing/workbench/workbench_workspace.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

final class WorkbenchScreen extends ConsumerWidget {
  const WorkbenchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(activeProjectProvider).valueOrNull;
    final hasProject = project != null;

    return ProjectWindowLifecycle(
      child: ColoredBox(
        color: AppColors.backgroundPrimary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const WorkbenchRibbon(),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: ColoredBox(
                      color: AppColors.surface,
                      child: hasProject
                          ? const WorkbenchWorkspace()
                          : const ProjectWelcomeScreen(),
                    ),
                  ),
                  if (hasProject) ...<Widget>[
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    const WorkbenchInspector(),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            const WorkbenchStatusBar(),
          ],
        ),
      ),
    );
  }
}
