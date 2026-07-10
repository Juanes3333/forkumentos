import 'package:flutter/material.dart';
import 'package:forkumentos/core/theme/app_theme.dart';
import 'package:forkumentos/routing/app_router.dart';

/// The root Widget of the application.
class App extends StatelessWidget {
  /// Creates a new [App] instance.
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Forkumentos',
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
