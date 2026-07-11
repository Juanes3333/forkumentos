import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';

final workbenchSelectionProvider =
    NotifierProvider<WorkbenchSelectionNotifier, WorkbenchSelectionState>(
      WorkbenchSelectionNotifier.new,
    );

final class WorkbenchSelectionNotifier
    extends Notifier<WorkbenchSelectionState> {
  @override
  WorkbenchSelectionState build() {
    return const WorkbenchSelectionState();
  }

  void updateSelection(
    DocumentTextSelection selection,
    Offset anchor, {
    Rect? bounds,
  }) {
    state = WorkbenchSelectionState(
      selection: selection,
      anchor: anchor,
      bounds: bounds,
    );
  }

  void clearSelection() {
    if (!state.hasSelection) {
      return;
    }
    state = const WorkbenchSelectionState();
  }
}

final class WorkbenchSelectionState {
  const WorkbenchSelectionState({this.selection, this.anchor, this.bounds});

  final DocumentTextSelection? selection;
  final Offset? anchor;

  /// Global selection bounds used to keep the tooltip clear of the text.
  final Rect? bounds;

  bool get hasSelection => selection != null && anchor != null;
}
