import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/routing/workbench/workbench_inspector.dart';
import 'package:forkumentos/routing/workbench/workbench_layout_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_ribbon.dart';
import 'package:forkumentos/routing/workbench/workbench_status_bar.dart';
import 'package:forkumentos/routing/workbench/workbench_workspace.dart';

final class WorkbenchScreen extends ConsumerWidget {
  const WorkbenchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final inspectorVisible = ref.watch(workbenchInspectorVisibleProvider);

    return ColoredBox(
      color: colors.backgroundPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const WorkbenchRibbon(),
          Divider(height: 1, thickness: 1, color: colors.border),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: ColoredBox(
                    color: colors.surface,
                    child: const WorkbenchWorkspace(),
                  ),
                ),
                if (inspectorVisible) ...<Widget>[
                  VerticalDivider(width: 1, thickness: 1, color: colors.border),
                  const WorkbenchInspector(),
                ],
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: colors.border),
          const WorkbenchStatusBar(),
        ],
      ),
    );
  }
}
