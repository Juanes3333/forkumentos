import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_controller_provider.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_screen.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_paragraph_highlights.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_navigation_provider.dart';
import 'package:forkumentos/features/preview/presentation/preview_state_provider.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_layout_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_selection_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_selection_tooltip.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';
import 'package:forkumentos/shared/widgets/mapping_aware_paragraph.dart';

final class WorkbenchWorkspace extends ConsumerStatefulWidget {
  const WorkbenchWorkspace({super.key});

  @override
  ConsumerState<WorkbenchWorkspace> createState() => _WorkbenchWorkspaceState();
}

final class _WorkbenchWorkspaceState extends ConsumerState<WorkbenchWorkspace> {
  final GlobalKey _documentStackKey = GlobalKey();
  final ValueNotifier<int> _highlightTick = ValueNotifier<int>(0);
  int? _focusPageIndex;
  int _focusToken = 0;
  Timer? _emphasisTimer;

  @override
  void dispose() {
    _emphasisTimer?.cancel();
    _highlightTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen<MappingNavigationRequest?>(mappingNavigationProvider, (
        previous,
        next,
      ) {
        if (next == null) {
          return;
        }
        _handleNavigation(next.target);
      })
      // Hover bumps highlight tick only — skips DocumentViewer rebuild.
      ..listen<int?>(
        activeMappingProvider.select(
          (session) => session.state.hoveredFieldIndex,
        ),
        (previous, next) {
          if (previous == next) {
            return;
          }
          _highlightTick.value++;
        },
      );

    final templateState = ref.watch(activeTemplateProvider);
    final templatePath = templateState.valueOrNull?.sourcePath;
    final reviewMode = ref.watch(workbenchReviewRenderModeProvider);
    final datasource = ref.watch(activeDatasourceProvider).valueOrNull;
    final headers = datasource?.headers ?? const <String>[];
    final assignments = ref.watch(
      activeMappingProvider.select((session) => session.state.assignments),
    );
    final currentFieldIndex = ref.watch(
      activeMappingProvider.select(
        (session) => session.state.currentFieldIndex,
      ),
    );
    final previewDocumentState = ref.watch(previewDocumentProvider);
    final previewRowIndex = ref.watch(
      previewStateProvider.select((state) => state.rowIndex),
    );
    final selectionState = ref.watch(workbenchSelectionProvider);
    final emphasizedAssignmentId = ref.watch(emphasizedAssignmentIdProvider);
    final viewerController = ref.watch(documentViewerControllerProvider);
    final isPreview = reviewMode == WorkbenchReviewRenderMode.preview;

    if (templatePath == null) {
      if (templateState.isLoading) {
        return const _CenteredStatus(
          title: 'Cargando plantilla...',
          showProgress: true,
        );
      }

      return const _CenteredStatus(
        title: 'Importa una plantilla DOCX o PDF para visualizar el documento.',
        description:
            'Usa la pestaña Plantillas del ribbon o arrastra un archivo '
            'a la ventana.',
      );
    }

    return Stack(
      key: _documentStackKey,
      children: <Widget>[
        DocumentViewerScreen(
          key: isPreview ? ValueKey<int>(previewRowIndex) : null,
          documentPath: templatePath,
          isSourceLoading:
              templateState.isLoading ||
              (isPreview &&
                  previewDocumentState.isLoading &&
                  previewDocumentState.valueOrNull == null),
          sourceErrorMessage: _resolveTemplateErrorMessage(templateState.error),
          documentOverride: isPreview ? previewDocumentState : null,
          showToolbar: false,
          controller: viewerController,
          focusPageIndex: _focusPageIndex,
          focusToken: _focusToken,
          viewerOverlay: DocumentViewerOverlay(
            highlightListenable: _highlightTick,
            highlightBuilder: isPreview
                ? (_) => const <ParagraphHighlightSegment>[]
                : (path) => buildParagraphHighlights(
                    path: path,
                    assignments: assignments,
                    suggestions: const [],
                    hoveredFieldIndex: ref
                        .read(activeMappingProvider)
                        .state
                        .hoveredFieldIndex,
                    activeFieldIndex: currentFieldIndex,
                    emphasizedAssignmentId: emphasizedAssignmentId,
                  ),
            // null (not empty callback): SelectableText would stale TextSpans.
            onSelectionChanged: isPreview || headers.isEmpty
                ? null
                : _handleSelectionChanged,
          ),
        ),
        if (!isPreview && selectionState.hasSelection)
          WorkbenchSelectionTooltip(stackKey: _documentStackKey),
      ],
    );
  }

  void _handleSelectionChanged(DocumentTextSelection? selection) {
    if (selection == null || selection.anchor == null) {
      ref.read(workbenchSelectionProvider.notifier).clearSelection();
      return;
    }
    ref
        .read(workbenchSelectionProvider.notifier)
        .updateSelection(
          selection,
          selection.anchor!,
          bounds: selection.bounds,
        );
  }

  void _handleNavigation(MappingNavigationTarget target) {
    switch (target) {
      case DatasourceFieldNavigationTarget(:final fieldIndex):
        ref
            .read(activeMappingProvider.notifier)
            .setCurrentFieldIndex(fieldIndex);
      case AssignmentNavigationTarget(:final assignmentId):
        final assignment = ref
            .read(activeMappingProvider)
            .state
            .assignments
            .firstWhereOrNull((item) => item.id == assignmentId);
        if (assignment == null) {
          return;
        }
        _focusAssignment(assignment);
      case DocumentPlaceholderNavigationTarget(:final path):
        setState(() {
          _focusPageIndex = path.pageIndex;
          _focusToken++;
        });
        ref.read(emphasizedAssignmentIdProvider.notifier).state = null;
    }
  }

  void _focusAssignment(FieldAssignment assignment) {
    setState(() {
      _focusPageIndex = assignment.path.pageIndex;
      _focusToken++;
    });
    ref
        .read(activeMappingProvider.notifier)
        .setCurrentFieldIndex(assignment.fieldIndex);
    ref.read(emphasizedAssignmentIdProvider.notifier).state = assignment.id;
    _emphasisTimer?.cancel();
    _emphasisTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      ref.read(emphasizedAssignmentIdProvider.notifier).state = null;
    });
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

final class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({
    required this.title,
    this.description,
    this.showProgress = false,
  });

  final String title;
  final String? description;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (description != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(description!),
                ],
                if (showProgress) ...<Widget>[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
