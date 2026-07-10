import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/presentation/datasource_management_screen.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_screen.dart';
import 'package:forkumentos/features/project/presentation/project_welcome_screen.dart';
import 'package:forkumentos/features/project/presentation/project_workbench_screen.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/features/template/presentation/template_management_screen.dart';
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
          GoRoute(
            path: '/project/template',
            builder: (BuildContext context, GoRouterState state) {
              return const TemplateManagementScreen();
            },
          ),
          GoRoute(
            path: '/project/datasource',
            builder: (BuildContext context, GoRouterState state) {
              return const DatasourceManagementScreen();
            },
          ),
          GoRoute(
            path: '/project/document',
            builder: (BuildContext context, GoRouterState state) {
              return const _DocumentViewerRoute();
            },
          ),
        ],
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      if (!canRedirect) {
        return null;
      }

      final isProjectRoute = state.matchedLocation.startsWith('/project');

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

final class _DocumentViewerRoute extends ConsumerWidget {
  const _DocumentViewerRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateState = ref.watch(activeTemplateProvider);
    return DocumentViewerScreen(
      documentPath: templateState.valueOrNull?.sourcePath,
      isSourceLoading: templateState.isLoading,
      sourceErrorMessage: _resolveTemplateErrorMessage(templateState.error),
    );
  }
}

String? _resolveTemplateErrorMessage(Object? error) {
  if (error == null) {
    return null;
  }

  if (error is TemplateLifecycleException) {
    return error.message;
  }

  return 'No se pudo cargar la plantilla activa.';
}
