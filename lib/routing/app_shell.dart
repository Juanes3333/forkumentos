import 'package:flutter/material.dart';
import 'package:forkumentos/core/theme/app_colors.dart';

final class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const double _sidebarWidth = 72;
  static const double _statusBarHeight = 28;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            const SizedBox(
              height: _statusBarHeight,
              child: ColoredBox(
                color: AppColors.backgroundSecondary,
                child: Row(
                  children: <Widget>[
                    SizedBox(width: _sidebarWidth),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
