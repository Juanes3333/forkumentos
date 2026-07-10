import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/project/presentation/project_window_lifecycle.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

final class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const double _sidebarWidth = 72;
  static const double _statusBarHeight = 28;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProject = ref.watch(activeProjectProvider).valueOrNull;
    final statusText = activeProject == null
        ? 'Sin proyecto activo'
        : 'Proyecto activo: ${activeProject.name}';

    return ProjectWindowLifecycle(
      child: Scaffold(
        body: ColoredBox(
          color: AppColors.backgroundPrimary,
          child: Column(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    const SizedBox(
                      width: _sidebarWidth,
                      child: ColoredBox(color: AppColors.backgroundSecondary),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: ColoredBox(color: AppColors.surface, child: child),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              SizedBox(
                height: _statusBarHeight,
                child: ColoredBox(
                  color: AppColors.backgroundSecondary,
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: _sidebarWidth),
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.foregroundMuted),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
