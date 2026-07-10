import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_screen.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_paragraph_highlights.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_navigation_provider.dart';
import 'package:forkumentos/features/preview/presentation/preview_state_provider.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_selection_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_tab.dart';
import 'package:forkumentos/routing/workbench/workbench_tab_provider.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';

final class WorkbenchWorkspace extends ConsumerStatefulWidget {
  const WorkbenchWorkspace({super.key});

  @override
  ConsumerState<WorkbenchWorkspace> createState() => _WorkbenchWorkspaceState();
}

final class _WorkbenchWorkspaceState extends ConsumerState<WorkbenchWorkspace> {
  int? _focusPageIndex;
  int _focusToken = 0;
  Timer? _emphasisTimer;

  @override
  void dispose() {
    _emphasisTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MappingNavigationRequest?>(mappingNavigationProvider, (
      previous,
      next,
    ) {
      if (next == null) {
        return;
      }
      _handleNavigation(next.target);
    });

    final templateState = ref.watch(activeTemplateProvider);
    final templatePath = templateState.valueOrNull?.sourcePath;
    final activeTab = ref.watch(workbenchTabProvider);
    final datasource = ref.watch(activeDatasourceProvider).valueOrNull;
    final headers = datasource?.headers ?? const <String>[];
    final mappingState = ref.watch(activeMappingProvider).state;
    final previewDocumentState = ref.watch(previewDocumentProvider);
    final previewDocument = previewDocumentState.valueOrNull;
    final previewRow =
        ref.watch(previewRecordProvider).valueOrNull ?? const <String?>[];
    final selectionState = ref.watch(workbenchSelectionProvider);
    final emphasizedAssignmentId = ref.watch(emphasizedAssignmentIdProvider);

    if (templatePath == null) {
      if (templateState.isLoading) {
        return const _CenteredStatus(
          title: 'Cargando plantilla...',
          showProgress: true,
        );
      }

      return const _CenteredStatus(
        title: 'Importa una plantilla DOCX para visualizar el documento.',
        description:
            'Usa la pestaña Plantilla del ribbon para seleccionar un archivo.',
      );
    }

    return Stack(
      children: <Widget>[
        DocumentViewerScreen(
          documentPath: templatePath,
          isSourceLoading:
              templateState.isLoading ||
              (previewDocumentState.isLoading &&
                  previewDocumentState.valueOrNull == null),
          sourceErrorMessage: _resolveTemplateErrorMessage(templateState.error),
          documentOverride: previewDocumentState,
          showToolbar: activeTab == WorkbenchTab.view,
          focusPageIndex: _focusPageIndex,
          focusToken: _focusToken,
          viewerOverlay: previewDocument == null
              ? null
              : DocumentViewerOverlay(
                  highlightBuilder: (path) => buildParagraphHighlights(
                    path: path,
                    assignments: mappingState.assignments,
                    suggestions: const [],
                    hoveredFieldIndex: mappingState.hoveredFieldIndex,
                    activeFieldIndex: mappingState.currentFieldIndex,
                    emphasizedAssignmentId: activeTab == WorkbenchTab.review
                        ? emphasizedAssignmentId
                        : null,
                  ),
                  onSelectionChanged: headers.isEmpty
                      ? (_) {}
                      : _handleSelectionChanged,
                ),
        ),
        if (selectionState.hasSelection)
          Positioned(
            left: selectionState.anchor!.dx.clamp(
              16.0,
              MediaQuery.of(context).size.width - 236,
            ),
            top: selectionState.anchor!.dy.clamp(
              16.0,
              MediaQuery.of(context).size.height - 72,
            ),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      blurRadius: 8,
                      color: Color(0x12000000),
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    _selectionOverlayLabel(
                      ref: ref,
                      headers: headers,
                      currentFieldIndex: mappingState.currentFieldIndex,
                      previewRow: previewRow,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ),
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
        .updateSelection(selection, selection.anchor!);
  }

  String? _previewValueForField(List<String?> previewRow, int fieldIndex) {
    if (fieldIndex < 0 || fieldIndex >= previewRow.length) {
      return null;
    }
    return previewRow[fieldIndex];
  }

  String _selectionRowSuffix(
    WidgetRef ref,
    List<String?> previewRow,
    int fieldIndex,
  ) {
    if (_previewValueForField(previewRow, fieldIndex) == null) {
      return '';
    }

    final previewState = ref.watch(previewStateProvider);
    return ' · fila ${previewState.rowIndex + 1}';
  }

  String _selectionOverlayLabel({
    required WidgetRef ref,
    required List<String> headers,
    required int currentFieldIndex,
    required List<String?> previewRow,
  }) {
    return 'Selección activa · ${headers[currentFieldIndex]}'
        '${_selectionRowSuffix(ref, previewRow, currentFieldIndex)}';
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
