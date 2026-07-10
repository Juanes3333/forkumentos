import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_theme.dart';
import 'package:forkumentos/routing/app_router.dart';

/// The root Widget of the application.
class App extends ConsumerWidget {
  /// Creates a new [App] instance.
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Forkumentos',
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
