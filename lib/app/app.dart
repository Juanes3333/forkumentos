import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/app/app_splash.dart';
import 'package:forkumentos/core/theme/app_theme.dart';
import 'package:forkumentos/routing/app_router.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';

/// The root Widget of the application.
class App extends ConsumerWidget {
  /// Creates a new [App] instance.
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Forkumentos',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return AppSplash(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
