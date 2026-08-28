import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/presentation/recent_projects_provider.dart';
import 'package:forkumentos/routing/app_phase_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

/// Keep-alive listener that reacts to a project becoming active *by being
/// loaded from disk* (as opposed to a freshly created one): it records the
/// project in the recent list and, when the `.fork` already carries both
/// embedded resources, jumps straight to the workbench.
///
/// This lives in a provider — not a widget's `ref.listen` — because the screen
/// that starts an "abrir proyecto" (landing) is torn down the instant the
/// project becomes active. A `WidgetRef` captured there is already disposed by
/// the time the reaction runs, which is the crash behind "abrir proyecto no
/// hace nada". `App` keeps this alive with `ref.watch(...)`.
final projectActivationListenerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<Project?>>(activeProjectProvider, (previous, next) {
    onProjectActivated(
      ref,
      previous: previous?.valueOrNull,
      next: next.valueOrNull,
    );
  });
});

@visibleForTesting
void onProjectActivated(
  Ref ref, {
  required Project? previous,
  required Project? next,
}) {
  if (next == null || next.id == previous?.id) {
    return;
  }

  final filePath = next.filePath;
  // Loaded projects arrive with isDirty == false and a real filePath; created
  // ones are dirty and path-less. Only the former belong in "recientes".
  final loadedFromDisk =
      filePath != null && filePath.isNotEmpty && !next.isDirty;
  if (!loadedFromDisk) {
    return;
  }

  unawaited(
    ref
        .read(recentProjectsProvider.notifier)
        .record(filePath: filePath, name: next.name),
  );

  final templatePath = next.embeddedTemplatePath;
  final datasourcePath = next.embeddedDatasourcePath;
  final hasBothResources =
      templatePath != null &&
      templatePath.isNotEmpty &&
      datasourcePath != null &&
      datasourcePath.isNotEmpty;
  if (hasBothResources) {
    ref.read(workbenchEnteredProvider.notifier).enterWorkbench();
  }
}
