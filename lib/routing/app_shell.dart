import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/project/presentation/project_welcome_screen.dart';
import 'package:forkumentos/features/project/presentation/project_window_lifecycle.dart';
import 'package:forkumentos/routing/app_phase_provider.dart';
import 'package:forkumentos/routing/project_wizard_screen.dart';
import 'package:forkumentos/routing/workbench/workbench_screen.dart';

final class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(appPhaseProvider);

    return ProjectWindowLifecycle(
      child: ColoredBox(
        color: AppColors.backgroundPrimary,
        child: switch (phase) {
          AppPhase.landing => const ProjectWelcomeScreen(),
          AppPhase.wizard => const ProjectWizardScreen(),
          AppPhase.workbench => const WorkbenchScreen(),
        },
      ),
    );
  }
}
