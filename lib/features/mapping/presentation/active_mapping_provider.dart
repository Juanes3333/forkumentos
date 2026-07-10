import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/mapping/domain/document_text_catalog.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_commands.dart';
import 'package:forkumentos/features/mapping/domain/mapping_state.dart';
import 'package:forkumentos/features/mapping/domain/text_occurrence.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:uuid/uuid.dart';

final activeMappingProvider =
    NotifierProvider<ActiveMappingNotifier, MappingSession>(
      ActiveMappingNotifier.new,
    );

final class MappingSession {
  const MappingSession({
    required this.state,
    required this.canUndo,
    required this.canRedo,
  });

  final MappingState state;
  final bool canUndo;
  final bool canRedo;
}

final class ActiveMappingNotifier extends Notifier<MappingSession> {
  final Uuid _uuid = const Uuid();
  final List<MappingState> _undoStack = <MappingState>[];
  final List<MappingState> _redoStack = <MappingState>[];

  @override
  MappingSession build() {
    ref.listen<String?>(
      activeProjectProvider.select(
        (projectState) => projectState.valueOrNull?.id,
      ),
      (String? previousProjectId, String? nextProjectId) {
        if (previousProjectId == nextProjectId) {
          return;
        }
        _resetHistory(const MappingState(assignments: <FieldAssignment>[]));
      },
    );

    return const MappingSession(
      state: MappingState(assignments: <FieldAssignment>[]),
      canUndo: false,
      canRedo: false,
    );
  }

  void setCurrentFieldIndex(int fieldIndex) {
    if (fieldIndex == state.state.currentFieldIndex) {
      return;
    }
    _updateState(state.state.copyWith(currentFieldIndex: fieldIndex));
  }

  void setHoveredFieldIndex(int? fieldIndex) {
    if (fieldIndex == state.state.hoveredFieldIndex) {
      return;
    }
    _updateState(state.state.copyWith(hoveredFieldIndex: fieldIndex));
  }

  FieldAssignment? findConflictingAssignment(DocumentTextSelection selection) {
    return findOverlappingAssignment(
      assignments: state.state.assignments,
      path: selection.path,
      startOffset: selection.startOffset,
      endOffset: selection.endOffset,
    );
  }

  List<TextOccurrence> findAdditionalOccurrences({
    required Document document,
    required FieldAssignment primaryAssignment,
  }) {
    final allMatches = findExactTextOccurrences(
      document: document,
      needle: primaryAssignment.selectedText,
    );

    return allMatches
        .where(
          (occurrence) => !occurrencesMatch(
            occurrence: occurrence,
            path: primaryAssignment.path,
            startOffset: primaryAssignment.startOffset,
            endOffset: primaryAssignment.endOffset,
          ),
        )
        .toList();
  }

  void confirmAssignment({
    required DocumentTextSelection selection,
    required String fieldHeader,
    required int fieldIndex,
    required int headerCount,
    List<TextOccurrence> extraOccurrences = const <TextOccurrence>[],
  }) {
    final trimmed = selection.selectedText.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final newAssignments = <FieldAssignment>[
      FieldAssignment(
        id: _uuid.v4(),
        fieldIndex: fieldIndex,
        fieldHeader: fieldHeader,
        selectedText: trimmed,
        path: selection.path,
        startOffset: selection.startOffset,
        endOffset: selection.endOffset,
      ),
      for (final occurrence in extraOccurrences)
        FieldAssignment(
          id: _uuid.v4(),
          fieldIndex: fieldIndex,
          fieldHeader: fieldHeader,
          selectedText: occurrence.matchedText,
          path: occurrence.path,
          startOffset: occurrence.startOffset,
          endOffset: occurrence.endOffset,
        ),
    ];

    _applyMutation(
      state.state.copyWith(
        assignments: <FieldAssignment>[
          ...state.state.assignments,
          ...newAssignments,
        ],
        currentFieldIndex: _nextUnmappedFieldIndex(
          fieldCount: headerCount,
          afterIndex: fieldIndex,
        ),
      ),
    );
    ref.read(activeProjectProvider.notifier).markProjectDirty();
  }

  void replaceAssignment({
    required FieldAssignment existingAssignment,
    required DocumentTextSelection selection,
    required String fieldHeader,
    required int fieldIndex,
    List<TextOccurrence> extraOccurrences = const <TextOccurrence>[],
  }) {
    final withoutExisting = state.state.assignments
        .where((assignment) => assignment.id != existingAssignment.id)
        .toList();

    final trimmed = selection.selectedText.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final replacement = <FieldAssignment>[
      FieldAssignment(
        id: _uuid.v4(),
        fieldIndex: fieldIndex,
        fieldHeader: fieldHeader,
        selectedText: trimmed,
        path: selection.path,
        startOffset: selection.startOffset,
        endOffset: selection.endOffset,
      ),
      for (final occurrence in extraOccurrences)
        FieldAssignment(
          id: _uuid.v4(),
          fieldIndex: fieldIndex,
          fieldHeader: fieldHeader,
          selectedText: occurrence.matchedText,
          path: occurrence.path,
          startOffset: occurrence.startOffset,
          endOffset: occurrence.endOffset,
        ),
    ];

    _applyMutation(
      state.state.copyWith(
        assignments: <FieldAssignment>[...withoutExisting, ...replacement],
      ),
    );
    ref.read(activeProjectProvider.notifier).markProjectDirty();
  }

  void removeAssignmentsForField(int fieldIndex) {
    final nextAssignments = removeFieldAssignments(
      state.state.assignments,
      fieldIndex,
    );
    if (nextAssignments.length == state.state.assignments.length) {
      return;
    }

    _applyMutation(
      state.state.copyWith(
        assignments: nextAssignments,
        currentFieldIndex: fieldIndex,
      ),
    );
    ref.read(activeProjectProvider.notifier).markProjectDirty();
  }

  void undo() {
    if (_undoStack.isEmpty) {
      return;
    }

    final previous = _undoStack.removeLast();
    _redoStack.add(state.state);
    _updateState(previous);
    ref.read(activeProjectProvider.notifier).markProjectDirty();
  }

  void redo() {
    if (_redoStack.isEmpty) {
      return;
    }

    final next = _redoStack.removeLast();
    _undoStack.add(state.state);
    _updateState(next);
    ref.read(activeProjectProvider.notifier).markProjectDirty();
  }

  int _nextUnmappedFieldIndex({
    required int fieldCount,
    required int afterIndex,
  }) {
    for (var index = afterIndex + 1; index < fieldCount; index++) {
      if (state.state.assignments.every((a) => a.fieldIndex != index)) {
        return index;
      }
    }

    for (var index = 0; index < fieldCount; index++) {
      if (state.state.assignments.every((a) => a.fieldIndex != index)) {
        return index;
      }
    }

    return afterIndex;
  }

  void _applyMutation(MappingState next) {
    _undoStack.add(state.state);
    _redoStack.clear();
    _updateState(next);
  }

  void _updateState(MappingState next) {
    state = MappingSession(
      state: next,
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
  }

  void _resetHistory(MappingState next) {
    _undoStack.clear();
    _redoStack.clear();
    _updateState(next);
  }
}
