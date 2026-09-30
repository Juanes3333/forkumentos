import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/mapping/data/mapping_json.dart';
import 'package:forkumentos/features/mapping/domain/auto_mapping.dart';
import 'package:forkumentos/features/mapping/domain/document_text_catalog.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/header_mismatch.dart';
import 'package:forkumentos/features/mapping/domain/mapping_commands.dart';
import 'package:forkumentos/features/mapping/domain/mapping_state.dart';
import 'package:forkumentos/features/mapping/domain/text_occurrence.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/models/document_text_path_resolver.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/document_content_provider.dart';
import 'package:uuid/uuid.dart';

final activeMappingProvider =
    NotifierProvider<ActiveMappingNotifier, MappingSession>(
      ActiveMappingNotifier.new,
    );

/// Id de la asignación que está esperando que el usuario seleccione texto
/// para cerrar el extremo final de un rango cruzado entre párrafos, o `null`
/// si no hay ninguna asignación en ese estado. Vive fuera de [MappingState]
/// (el modelo de dominio) porque es puramente un modo de interacción de la
/// UI: no se persiste ni forma parte del mapeo en sí.
final pendingRangeCloseAssignmentIdProvider = StateProvider<String?>(
  (ref) => null,
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
    final initialProject = ref.read(activeProjectProvider).valueOrNull;
    ref.listen<({String? id, List<Map<String, dynamic>> assignments})>(
      activeProjectProvider.select((projectState) {
        final project = projectState.valueOrNull;
        return (
          id: project?.id,
          assignments: project?.mappingAssignments ?? <Map<String, dynamic>>[],
        );
      }),
      (previousProject, nextProject) {
        if (previousProject?.id == nextProject.id) {
          return;
        }
        _resetHistory(
          MappingState(
            assignments: mappingAssignmentsFromJson(nextProject.assignments),
          ),
        );
      },
    );

    return MappingSession(
      state: MappingState(
        assignments: mappingAssignmentsFromJson(
          initialProject?.mappingAssignments ?? <Map<String, dynamic>>[],
        ),
      ),
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
        .where(
          (occurrence) =>
              findOverlappingAssignment(
                assignments: state.state.assignments,
                path: occurrence.path,
                startOffset: occurrence.startOffset,
                endOffset: occurrence.endOffset,
              ) ==
              null,
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

    final leadingWhitespace =
        selection.selectedText.length -
        selection.selectedText.trimLeft().length;
    final trailingWhitespace =
        selection.selectedText.length -
        selection.selectedText.trimRight().length;

    final newAssignments = <FieldAssignment>[
      FieldAssignment(
        id: _uuid.v4(),
        fieldIndex: fieldIndex,
        fieldHeader: fieldHeader,
        selectedText: trimmed,
        path: selection.path,
        startOffset: selection.startOffset + leadingWhitespace,
        endOffset: selection.endOffset - trailingWhitespace,
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
    _syncProjectAssignments();
  }

  /// Aplica un auto-mapeo ya calculado como un único paso de undo.
  /// Devuelve cuántas asignaciones se agregaron (0 si ninguna).
  ///
  /// Se aparta a propósito de `autoMapFromFirstRow`, el método que nombra
  /// `.claude/10-auto-mapping/task.md`: el flujo elegido avisa antes de
  /// aplicar, así que quien llama necesita ver el [AutoMappingResult] —y sus
  /// `occurrenceCountsByField`— para confirmar con el usuario antes de mutar.
  /// Un método que calculara y mutara a la vez haría imposible ese paso
  /// previo. Quien llama arma el resultado con [buildAutoMapping], que es
  /// público y puro justamente para eso.
  ///
  /// Sin asignaciones nuevas no se toca el estado ni el historial.
  int applyAutoMapping(AutoMappingResult result) {
    if (result.assignments.isEmpty) {
      return 0;
    }

    _applyMutation(
      state.state.copyWith(
        assignments: <FieldAssignment>[
          ...state.state.assignments,
          ...result.assignments,
        ],
      ),
    );
    _syncProjectAssignments();
    return result.assignments.length;
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

    final leadingWhitespace =
        selection.selectedText.length -
        selection.selectedText.trimLeft().length;
    final trailingWhitespace =
        selection.selectedText.length -
        selection.selectedText.trimRight().length;

    final replacement = <FieldAssignment>[
      FieldAssignment(
        id: _uuid.v4(),
        fieldIndex: fieldIndex,
        fieldHeader: fieldHeader,
        selectedText: trimmed,
        path: selection.path,
        startOffset: selection.startOffset + leadingWhitespace,
        endOffset: selection.endOffset - trailingWhitespace,
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
    _syncProjectAssignments();
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
    _syncProjectAssignments();
  }

  void setAssignmentIsListField({
    required String assignmentId,
    required bool isListField,
  }) {
    final index = state.state.assignments.indexWhere(
      (assignment) => assignment.id == assignmentId,
    );
    if (index == -1 ||
        state.state.assignments[index].isListField == isListField) {
      return;
    }

    final nextAssignments = <FieldAssignment>[...state.state.assignments];
    nextAssignments[index] = nextAssignments[index].copyWith(
      isListField: isListField,
    );

    _applyMutation(state.state.copyWith(assignments: nextAssignments));
    _syncProjectAssignments();
  }

  /// Actualiza el `fieldHeader` de las asignaciones afectadas por
  /// [mismatches] para que coincida con la nueva fuente de datos.
  void updateFieldHeaders(List<HeaderMismatch> mismatches) {
    final current = state.state.assignments;
    final nextAssignments = applyHeaderMismatches(current, mismatches);
    var changed = false;
    for (var i = 0; i < current.length; i++) {
      if (current[i].fieldHeader != nextAssignments[i].fieldHeader) {
        changed = true;
        break;
      }
    }
    if (!changed) {
      return;
    }

    _applyMutation(state.state.copyWith(assignments: nextAssignments));
    _syncProjectAssignments();
  }

  /// Pone la aplicación en modo "esperando selección para cerrar el rango"
  /// de [assignmentId]. La próxima selección de texto que llegue al
  /// `DocumentViewer` debe resolverse llamando a [completeRangeClose] en vez
  /// de crear una asignación nueva.
  void beginRangeClose(String assignmentId) {
    final notifier = ref.read(pendingRangeCloseAssignmentIdProvider.notifier);
    if (notifier.state == assignmentId) {
      return;
    }
    notifier.state = assignmentId;
  }

  /// Sale del modo "esperando selección para cerrar el rango" sin modificar
  /// ninguna asignación.
  void cancelRangeClose() {
    ref.read(pendingRangeCloseAssignmentIdProvider.notifier).state = null;
  }

  /// Cierra el rango cruzado entre párrafos de la asignación pendiente
  /// (ver [beginRangeClose]) con la selección [selection] como su extremo
  /// final: actualiza `endPath`/`endOffset` en lugar de crear una asignación
  /// nueva. No hace nada si no hay ninguna asignación pendiente.
  void completeRangeClose(DocumentTextSelection selection) {
    final assignmentId = ref.read(pendingRangeCloseAssignmentIdProvider);
    if (assignmentId == null) {
      return;
    }

    final index = state.state.assignments.indexWhere(
      (assignment) => assignment.id == assignmentId,
    );
    if (index == -1) {
      cancelRangeClose();
      return;
    }

    final existing = state.state.assignments[index];
    final crossParagraphText = _buildCrossParagraphSelectedText(
      startPath: existing.path,
      startOffset: existing.startOffset,
      endPath: selection.path,
      endOffset: selection.endOffset,
    );

    final nextAssignments = <FieldAssignment>[...state.state.assignments];
    nextAssignments[index] = existing.copyWith(
      endPath: selection.path,
      endOffset: selection.endOffset,
      selectedText: crossParagraphText ?? existing.selectedText,
    );

    _applyMutation(state.state.copyWith(assignments: nextAssignments));
    _syncProjectAssignments();
    cancelRangeClose();
  }

  /// Reconstruye el `selectedText` completo de un rango cruzado entre
  /// párrafos: sufijo de `startPath` desde `startOffset`, texto íntegro de
  /// cada párrafo intermedio (si los hay) y prefijo de `endPath` hasta
  /// `endOffset`, unidos por `\n` — el mismo formato que usa
  /// `findExactTextOccurrences` para representar un salto de párrafo en un
  /// rango. `null` si el documento activo no está disponible o si alguna
  /// ruta no resuelve, en cuyo caso quien llama conserva el `selectedText`
  /// anterior en vez de fallar.
  String? _buildCrossParagraphSelectedText({
    required DocumentTextPath startPath,
    required int startOffset,
    required DocumentTextPath endPath,
    required int endOffset,
  }) {
    final templatePath = ref
        .read(activeTemplateProvider)
        .valueOrNull
        ?.sourcePath;
    if (templatePath == null) {
      return null;
    }
    final document = ref
        .read(documentContentProvider(templatePath))
        .valueOrNull;
    if (document == null) {
      return null;
    }

    try {
      final startText = paragraphPlainText(
        resolveParagraph(document, startPath),
      );
      final endText = paragraphPlainText(resolveParagraph(document, endPath));
      if (startOffset < 0 || startOffset > startText.length) {
        return null;
      }
      if (endOffset < 0 || endOffset > endText.length) {
        return null;
      }

      final buffer = StringBuffer(startText.substring(startOffset));
      for (final middleText in _middleParagraphTexts(
        document,
        startPath,
        endPath,
      )) {
        buffer
          ..write('\n')
          ..write(middleText);
      }
      buffer
        ..write('\n')
        ..write(endText.substring(0, endOffset));
      return buffer.toString();
    } on DocumentTextPathResolutionException {
      return null;
    }
  }

  /// Textos íntegros de los párrafos estrictamente entre [startPath] y
  /// [endPath]. Replica a propósito (no reutiliza) el criterio de
  /// `_extendedParagraphPaths` en
  /// `lib/features/mapping/domain/mapping_paragraph_highlights.dart`: se
  /// detiene en el primer bloque que no es un párrafo, mismo contenedor
  /// (nivel raíz o misma celda de tabla). Se replica en vez de importarse
  /// porque ese archivo es dominio de MappingAgent — esta capa de
  /// presentación no lo modifica, solo lee el mismo criterio.
  List<String> _middleParagraphTexts(
    Document document,
    DocumentTextPath startPath,
    DocumentTextPath endPath,
  ) {
    final startSteps = startPath.steps;
    final endSteps = endPath.steps;
    if (startSteps.isEmpty ||
        endSteps.isEmpty ||
        startSteps.length != endSteps.length) {
      return const <String>[];
    }
    final firstStep = startSteps.first;
    final endFirstStep = endSteps.first;
    if (firstStep is! RootDocumentBlockStep ||
        endFirstStep is! RootDocumentBlockStep) {
      return const <String>[];
    }

    final bodyBlocks = <DocumentBlock>[
      for (final page in document.pages) ...page.blocks,
    ];

    if (startSteps.length == 1) {
      return _paragraphTextsBetween(
        blocks: bodyBlocks,
        startBlockIndex: firstStep.blockIndex,
        endBlockIndex: endFirstStep.blockIndex,
      );
    }

    if (startSteps.length != 2 ||
        firstStep.blockIndex != endFirstStep.blockIndex) {
      return const <String>[];
    }
    if (firstStep.blockIndex < 0 || firstStep.blockIndex >= bodyBlocks.length) {
      return const <String>[];
    }
    final tableBlock = bodyBlocks[firstStep.blockIndex];
    if (tableBlock is! DocumentTableBlock) {
      return const <String>[];
    }
    final cellStep = startSteps[1];
    final endCellStep = endSteps[1];
    if (cellStep is! DocumentTableCellBlockStep ||
        endCellStep is! DocumentTableCellBlockStep ||
        cellStep.rowIndex != endCellStep.rowIndex ||
        cellStep.cellIndex != endCellStep.cellIndex) {
      return const <String>[];
    }
    final rows = tableBlock.table.rows;
    if (cellStep.rowIndex < 0 || cellStep.rowIndex >= rows.length) {
      return const <String>[];
    }
    final cells = rows[cellStep.rowIndex].cells;
    if (cellStep.cellIndex < 0 || cellStep.cellIndex >= cells.length) {
      return const <String>[];
    }
    final cellBlocks = cells[cellStep.cellIndex].blocks;

    return _paragraphTextsBetween(
      blocks: cellBlocks,
      startBlockIndex: cellStep.blockIndex,
      endBlockIndex: endCellStep.blockIndex,
    );
  }

  /// Textos de los bloques párrafo estrictamente entre [startBlockIndex] y
  /// [endBlockIndex] (ambos exclusivos) dentro de [blocks]; se detiene en el
  /// primer bloque que no sea párrafo o esté fuera de rango.
  List<String> _paragraphTextsBetween({
    required List<DocumentBlock> blocks,
    required int startBlockIndex,
    required int endBlockIndex,
  }) {
    final texts = <String>[];
    for (
      var blockIndex = startBlockIndex + 1;
      blockIndex < endBlockIndex;
      blockIndex++
    ) {
      if (blockIndex < 0 || blockIndex >= blocks.length) {
        break;
      }
      final block = blocks[blockIndex];
      if (block is! DocumentParagraphBlock) {
        break;
      }
      texts.add(paragraphPlainText(block.paragraph));
    }
    return texts;
  }

  void removeAssignment(String assignmentId) {
    final nextAssignments = removeAssignmentsById(
      state.state.assignments,
      <String>{assignmentId},
    );
    if (nextAssignments.length == state.state.assignments.length) {
      return;
    }

    _applyMutation(state.state.copyWith(assignments: nextAssignments));
    _syncProjectAssignments();
  }

  void undo() {
    if (_undoStack.isEmpty) {
      return;
    }

    final previous = _undoStack.removeLast();
    _redoStack.add(state.state);
    _updateState(previous);
    _syncProjectAssignments();
  }

  void redo() {
    if (_redoStack.isEmpty) {
      return;
    }

    final next = _redoStack.removeLast();
    _undoStack.add(state.state);
    _updateState(next);
    _syncProjectAssignments();
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

  void _syncProjectAssignments() {
    ref
        .read(activeProjectProvider.notifier)
        .updateMappingAssignments(
          mappingAssignmentsToJson(state.state.assignments),
        );
  }
}
