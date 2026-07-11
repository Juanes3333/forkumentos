import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/app/app_splash.dart';
import 'package:forkumentos/core/launch/launch_arguments.dart';
import 'package:forkumentos/core/theme/app_theme.dart';
import 'package:forkumentos/routing/after_project_load.dart';
import 'package:forkumentos/routing/app_router.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';

/// The root Widget of the application.
class App extends ConsumerStatefulWidget {
  /// Creates a new [App] instance.
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

final class _AppState extends ConsumerState<App> {
  var _handledLaunchArgs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleLaunchArguments();
    });
  }

  Future<void> _handleLaunchArguments() async {
    if (_handledLaunchArgs) {
      return;
    }
    _handledLaunchArgs = true;

    // Skip under widget tests (same pattern as AppSplash).
    final underTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (underTest) {
      return;
    }

    final args = Platform.executableArguments;
    final projectPath = resolveLaunchProjectPath(args);
    final createNew = wantsNewProject(args);
    if (projectPath == null && !createNew) {
      return;
    }

    // loadProject / createProject need workspace paths from settings.
    await ref.read(settingsProvider.future);

    if (projectPath != null) {
      await ref
          .read(activeProjectProvider.notifier)
          .loadProject(filePath: projectPath);
      await afterSuccessfulProjectLoad(ref);
      return;
    }

    final paths = ref.read(workspacePathsProvider);
    final name = paths == null
        ? 'Proyecto 1'
        : await paths.nextAutomaticProjectName();
    await ref.read(activeProjectProvider.notifier).createProject(name: name);
  }

  @override
  Widget build(BuildContext context) {
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
