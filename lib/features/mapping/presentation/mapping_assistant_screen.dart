import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_screen.dart';
import 'package:forkumentos/features/mapping/domain/document_text_catalog.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_paragraph_highlights.dart';
import 'package:forkumentos/features/mapping/domain/text_occurrence.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/floating_mapping_menu.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/mapping_field_sidebar.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/mapping_preview_panel.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/multiple_occurrences_dialog.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';
import 'package:forkumentos/shared/providers/document_content_provider.dart';

final class MappingAssistantScreen extends ConsumerStatefulWidget {
  const MappingAssistantScreen({
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
  ConsumerState<MappingAssistantScreen> createState() =>
      _MappingAssistantScreenState();
}

final class _MappingAssistantScreenState
    extends ConsumerState<MappingAssistantScreen> {
  DocumentTextSelection? _pendingSelection;
  Offset? _menuPosition;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): _RedoIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) {
              ref.read(activeMappingProvider.notifier).undo();
              return null;
            },
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) {
              ref.read(activeMappingProvider.notifier).redo();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.sourceErrorMessage != null) {
      return _CenteredStatus(
        title: 'No se pudo preparar el asistente de mapeo.',
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
        title: 'Importa una plantilla y una fuente de datos para mapear.',
        description:
            'El asistente de mapeo requiere una plantilla DOCX y un archivo '
            'CSV/XLSX con encabezados.',
      );
    }

    final mappingSession = ref.watch(activeMappingProvider);
    final mappingState = mappingSession.state;
    final documentState = ref.watch(
      documentContentProvider(widget.documentPath!),
    );
    final document = documentState.valueOrNull;

    final previewValue = _previewValueForField(mappingState.currentFieldIndex);
    final suggestions = document == null
        ? const <TextOccurrence>[]
        : findExactTextOccurrences(
            document: document,
            needle: previewValue ?? '',
          );

    final assignmentCounts = List<int>.generate(widget.headers.length, (index) {
      return mappingState.assignments
          .where((assignment) => assignment.fieldIndex == index)
          .length;
    });

    return Stack(
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MappingPreviewPanel(
              headers: widget.headers,
              previewRow: widget.previewRow,
              currentFieldIndex: mappingState.currentFieldIndex,
              assignmentCounts: assignmentCounts,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: <Widget>[
                  Tooltip(
                    message: 'Deshacer (Ctrl+Z)',
                    child: IconButton(
                      onPressed: mappingSession.canUndo
                          ? ref.read(activeMappingProvider.notifier).undo
                          : null,
                      icon: const Icon(Icons.undo),
                    ),
                  ),
                  Tooltip(
                    message: 'Rehacer (Ctrl+Y)',
                    child: IconButton(
                      onPressed: mappingSession.canRedo
                          ? ref.read(activeMappingProvider.notifier).redo
                          : null,
                      icon: const Icon(Icons.redo),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Campo activo: '
                    '${widget.headers[mappingState.currentFieldIndex]}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: DocumentViewerScreen(
                      documentPath: widget.documentPath,
                      isSourceLoading: documentState.isLoading,
                      showToolbar: false,
                      viewerOverlay: document == null
                          ? null
                          : DocumentViewerOverlay(
                              highlightBuilder: (path) =>
                                  buildParagraphHighlights(
                                    path: path,
                                    assignments: mappingState.assignments,
                                    suggestions: suggestions,
                                    hoveredFieldIndex:
                                        mappingState.hoveredFieldIndex,
                                    activeFieldIndex:
                                        mappingState.currentFieldIndex,
                                  ),
                              onTextSelected: _handleTextSelected,
                            ),
                    ),
                  ),
                  MappingFieldSidebar(
                    headers: widget.headers,
                    currentFieldIndex: mappingState.currentFieldIndex,
                    assignmentCounts: assignmentCounts,
                    onFieldSelected: (index) {
                      ref
                          .read(activeMappingProvider.notifier)
                          .setCurrentFieldIndex(index);
                    },
                    onFieldHoverChanged: (index) {
                      ref
                          .read(activeMappingProvider.notifier)
                          .setHoveredFieldIndex(index);
                    },
                    onRemoveFieldAssignments: (index) {
                      ref
                          .read(activeMappingProvider.notifier)
                          .removeAssignmentsForField(index);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_pendingSelection != null && _menuPosition != null)
          Positioned(
            left: _menuPosition!.dx,
            top: _menuPosition!.dy,
            child: FloatingMappingMenu(
              fieldName: widget.headers[mappingState.currentFieldIndex],
              onConfirm: () => _confirmPendingSelection(document),
              onReject: _clearPendingSelection,
            ),
          ),
      ],
    );
  }

  String? _previewValueForField(int fieldIndex) {
    if (fieldIndex < 0 || fieldIndex >= widget.previewRow.length) {
      return null;
    }
    return widget.previewRow[fieldIndex];
  }

  void _handleTextSelected(DocumentTextSelection selection) {
    setState(() {
      _pendingSelection = selection;
      _menuPosition = const Offset(120, 160);
    });
  }

  void _clearPendingSelection() {
    setState(() {
      _pendingSelection = null;
      _menuPosition = null;
    });
  }

  Future<void> _confirmPendingSelection(Document? document) async {
    final selection = _pendingSelection;
    if (selection == null || document == null) {
      return;
    }

    final mappingNotifier = ref.read(activeMappingProvider.notifier);
    final mappingState = ref.read(activeMappingProvider).state;
    final fieldIndex = mappingState.currentFieldIndex;
    final fieldHeader = widget.headers[fieldIndex];

    final conflict = mappingNotifier.findConflictingAssignment(selection);
    if (conflict != null) {
      final shouldReplace = await _askReplaceAssignment(conflict);
      if (!shouldReplace) {
        _clearPendingSelection();
        return;
      }

      final primary = FieldAssignment(
        id: conflict.id,
        fieldIndex: fieldIndex,
        fieldHeader: fieldHeader,
        selectedText: selection.selectedText.trim(),
        path: selection.path,
        startOffset: selection.startOffset,
        endOffset: selection.endOffset,
      );
      final extras = await _resolveExtraOccurrences(document, primary);

      mappingNotifier.replaceAssignment(
        existingAssignment: conflict,
        selection: selection,
        fieldHeader: fieldHeader,
        fieldIndex: fieldIndex,
        extraOccurrences: extras,
      );
      _clearPendingSelection();
      return;
    }

    final primary = FieldAssignment(
      id: 'pending',
      fieldIndex: fieldIndex,
      fieldHeader: fieldHeader,
      selectedText: selection.selectedText.trim(),
      path: selection.path,
      startOffset: selection.startOffset,
      endOffset: selection.endOffset,
    );
    final extras = await _resolveExtraOccurrences(document, primary);

    mappingNotifier.confirmAssignment(
      selection: selection,
      fieldHeader: fieldHeader,
      fieldIndex: fieldIndex,
      headerCount: widget.headers.length,
      extraOccurrences: extras,
    );
    _clearPendingSelection();
  }

  Future<List<TextOccurrence>> _resolveExtraOccurrences(
    Document document,
    FieldAssignment primary,
  ) async {
    final additional = ref
        .read(activeMappingProvider.notifier)
        .findAdditionalOccurrences(
          document: document,
          primaryAssignment: primary,
        );
    if (additional.isEmpty) {
      return const <TextOccurrence>[];
    }

    if (!mounted) {
      return const <TextOccurrence>[];
    }

    final selected = await MultipleOccurrencesDialog.show(
      context,
      occurrences: additional,
    );
    return selected ?? const <TextOccurrence>[];
  }

  Future<bool> _askReplaceAssignment(FieldAssignment existing) async {
    if (!mounted) {
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Texto ya asignado'),
          content: Text(
            'Este texto ya pertenece al campo "${existing.fieldHeader}". '
            '¿Deseas reemplazar la asignación?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reemplazar'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

final class _UndoIntent extends Intent {
  const _UndoIntent();
}

final class _RedoIntent extends Intent {
  const _RedoIntent();
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
