import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the right workbench inspector panel is visible.
final workbenchInspectorVisibleProvider =
    NotifierProvider<WorkbenchInspectorVisibleNotifier, bool>(
      WorkbenchInspectorVisibleNotifier.new,
    );

final class WorkbenchInspectorVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() {
    state = !state;
  }
}

enum WorkbenchReviewRenderMode { mappingReview, preview }

/// Document rendering mode while the Revisión ribbon tab is active.
final workbenchReviewRenderModeProvider =
    NotifierProvider<
      WorkbenchReviewRenderModeNotifier,
      WorkbenchReviewRenderMode
    >(WorkbenchReviewRenderModeNotifier.new);

final class WorkbenchReviewRenderModeNotifier
    extends Notifier<WorkbenchReviewRenderMode> {
  @override
  WorkbenchReviewRenderMode build() => WorkbenchReviewRenderMode.mappingReview;

  WorkbenchReviewRenderMode get mode => state;

  set mode(WorkbenchReviewRenderMode mode) {
    state = mode;
  }
}
