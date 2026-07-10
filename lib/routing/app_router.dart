import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/project/presentation/project_welcome_screen.dart';
import 'package:forkumentos/features/project/presentation/project_workbench_screen.dart';
import 'package:forkumentos/routing/app_shell.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final activeProjectState = ref.watch(activeProjectProvider);
  final hasActiveProject = activeProjectState.valueOrNull != null;
  final canRedirect =
      !activeProjectState.isLoading && !activeProjectState.hasError;

  final router = GoRouter(
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return AppShell(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              return const ProjectWelcomeScreen();
            },
          ),
          GoRoute(
            path: '/project',
            builder: (BuildContext context, GoRouterState state) {
              return const ProjectWorkbenchScreen();
            },
          ),
        ],
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      if (!canRedirect) {
        return null;
      }

      final isProjectRoute = state.matchedLocation == '/project';

      if (hasActiveProject && !isProjectRoute) {
        return '/project';
      }
      if (!hasActiveProject && isProjectRoute) {
        return '/';
      }
      return null;
    },
  );

  ref.onDispose(router.dispose);
  return router;
});
