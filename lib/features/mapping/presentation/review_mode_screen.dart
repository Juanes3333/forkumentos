import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_screen.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_paragraph_highlights.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_navigation_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_provider.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/mapping_preview_panel.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/mapping_review_sidebar.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/review_panel.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';
import 'package:forkumentos/shared/providers/document_content_provider.dart';

final class ReviewModeScreen extends ConsumerStatefulWidget {
  const ReviewModeScreen({
    required this.documentPath,
    required this.headers,
    required this.previewRow,
    required this.isSourceLoading,
    this.sourceErrorMessage,
    super.key,
  });

  final String? documentPath;
  final List<String> headers;
  final List<String?> previewRow;
  final bool isSourceLoading;
  final String? sourceErrorMessage;

  @override
  ConsumerState<ReviewModeScreen> createState() => _ReviewModeScreenState();
}

final class _ReviewModeScreenState extends ConsumerState<ReviewModeScreen> {
  int? _focusedFieldIndex;
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

    if (widget.sourceErrorMessage != null) {
      return _CenteredStatus(
        title: 'No se pudo preparar el modo revisión.',
        description: widget.sourceErrorMessage,
        isError: true,
      );
    }

    if (widget.isSourceLoading) {
      return const _CenteredStatus(
        title: 'Cargando datos del proyecto...',
        showProgress: true,
      );
    }

    if (widget.documentPath == null || widget.headers.isEmpty) {
      return const _CenteredStatus(
        title: 'Importa una plantilla y una fuente de datos para revisar.',
        description:
            'El modo revisión requiere una plantilla DOCX y un archivo '
            'CSV/XLSX con encabezados.',
      );
    }

    final snapshot = ref.watch(mappingReviewProvider);
    if (snapshot == null) {
      return const _CenteredStatus(
        title: 'No hay datos suficientes para revisar el mapeo.',
      );
    }

    final mappingSession = ref.watch(activeMappingProvider);
    final mappingState = mappingSession.state;
    final documentState = ref.watch(
      documentContentProvider(widget.documentPath!),
    );
    final document = documentState.valueOrNull;
    final emphasizedAssignmentId = ref.watch(emphasizedAssignmentIdProvider);

    final assignmentCounts = List<int>.generate(widget.headers.length, (index) {
      return mappingState.assignments
          .where((assignment) => assignment.fieldIndex == index)
          .length;
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Row(
        key: const ValueKey<String>('review-mode'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ReviewPanel(
            snapshot: snapshot,
            headers: widget.headers,
            onExport: snapshot.isExportReady ? () {} : null,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                MappingPreviewPanel(
                  headers: widget.headers,
                  previewRow: widget.previewRow,
                  currentFieldIndex: mappingState.currentFieldIndex,
                  assignmentCounts: assignmentCounts,
                  focusedFieldIndex: _focusedFieldIndex,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        'Modo revisión',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          ref
                              .read(mappingWorkflowProvider.notifier)
                              .enterMapping();
                        },
                        icon: const Icon(Icons.alt_route_outlined),
                        label: const Text('Volver al mapeo'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: DocumentViewerScreen(
                    documentPath: widget.documentPath,
                    isSourceLoading: documentState.isLoading,
                    showToolbar: false,
                    focusPageIndex: _focusPageIndex,
                    focusToken: _focusToken,
                    viewerOverlay: document == null
                        ? null
                        : DocumentViewerOverlay(
                            highlightBuilder: (path) =>
                                buildParagraphHighlights(
                                  path: path,
                                  assignments: mappingState.assignments,
                                  suggestions: const [],
                                  hoveredFieldIndex:
                                      mappingState.hoveredFieldIndex,
                                  activeFieldIndex:
                                      mappingState.currentFieldIndex,
                                  emphasizedAssignmentId:
                                      emphasizedAssignmentId,
                                ),
                            onSelectionChanged: (_) {},
                          ),
                  ),
                ),
              ],
            ),
          ),
          MappingReviewSidebar(
            headers: widget.headers,
            assignments: mappingState.assignments,
            onRemoveAssignment: (assignmentId) {
              ref
                  .read(activeMappingProvider.notifier)
                  .removeAssignment(assignmentId);
            },
            onNavigateToAssignment: (assignmentId) {
              ref
                  .read(mappingNavigationProvider.notifier)
                  .navigateTo(AssignmentNavigationTarget(assignmentId));
            },
            onNavigateToField: (fieldIndex) {
              ref
                  .read(mappingNavigationProvider.notifier)
                  .navigateTo(DatasourceFieldNavigationTarget(fieldIndex));
            },
            onFieldHoverChanged: (fieldIndex) {
              ref
                  .read(activeMappingProvider.notifier)
                  .setHoveredFieldIndex(fieldIndex);
            },
          ),
        ],
      ),
    );
  }

  void _handleNavigation(MappingNavigationTarget target) {
    switch (target) {
      case DatasourceFieldNavigationTarget(:final fieldIndex):
        setState(() {
          _focusedFieldIndex = fieldIndex;
        });
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
      _focusedFieldIndex = assignment.fieldIndex;
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

final class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({
    required this.title,
    this.description,
    this.showProgress = false,
    this.isError = false,
  });

  final String title;
  final String? description;
  final bool showProgress;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          color: isError ? colorScheme.errorContainer : null,
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
