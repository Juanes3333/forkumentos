import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_color_palette.dart';
import 'package:forkumentos/features/mapping/domain/text_occurrence.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/models/document_text_path_resolver.dart';
import 'package:forkumentos/shared/widgets/mapping_aware_paragraph.dart';

List<ParagraphHighlightSegment> buildParagraphHighlights({
  required DocumentTextPath path,
  required List<FieldAssignment> assignments,
  required List<TextOccurrence> suggestions,
  required int? hoveredFieldIndex,
  required int activeFieldIndex,
  String? emphasizedAssignmentId,
  Document? document,
}) {
  final highlights = <ParagraphHighlightSegment>[];

  for (final assignment in assignments) {
    final endPath = assignment.endPath;
    final color = mappingColorForFieldIndex(assignment.fieldIndex);
    final emphasize =
        emphasizedAssignmentId == assignment.id ||
        hoveredFieldIndex == assignment.fieldIndex;

    if (assignment.path == path) {
      // A cross-paragraph assignment's `endOffset` belongs to `endPath`, not
      // to this (starting) paragraph, so this paragraph paints from
      // `startOffset` to its own end instead.
      final rangeEnd = endPath == null
          ? assignment.endOffset
          : (document == null
                ? assignment.endOffset
                : _paragraphTextLength(document, path) ?? assignment.endOffset);
      highlights.add(
        ParagraphHighlightSegment(
          startOffset: assignment.startOffset,
          endOffset: rangeEnd,
          color: color,
          emphasize: emphasize,
        ),
      );
      continue;
    }

    if (endPath != null && endPath == path) {
      highlights.add(
        ParagraphHighlightSegment(
          startOffset: 0,
          endOffset: assignment.endOffset,
          color: color,
          emphasize: emphasize,
        ),
      );
      continue;
    }

    if (document == null || endPath == null) {
      continue;
    }
    if (!_extendedParagraphPaths(document, assignment).contains(path)) {
      continue;
    }

    final extendedLength = _paragraphTextLength(document, path);
    if (extendedLength == null) {
      continue;
    }
    highlights.add(
      ParagraphHighlightSegment(
        startOffset: 0,
        endOffset: extendedLength,
        color: color,
        isExtendedParagraph: true,
      ),
    );
  }

  for (final suggestion in suggestions) {
    if (suggestion.path != path) {
      continue;
    }

    highlights.add(
      ParagraphHighlightSegment(
        startOffset: suggestion.startOffset,
        endOffset: suggestion.endOffset,
        color: mappingColorForFieldIndex(activeFieldIndex),
        isSuggestion: true,
      ),
    );
  }

  return highlights;
}

/// Rutas de los párrafos estrictamente entre `assignment.path` y
/// `assignment.endPath`, para pintarlos como extensión de campo prosa
/// multi-párrafo. Espeja el criterio de `_collectListGroup` en
/// `docx_zip_exporter.dart`: se detiene en el primer bloque que no sea un
/// párrafo (p. ej. una tabla) o al llegar al final del contenedor. Vacío
/// para campos de lista numerada (esos se auto-detectan por numId al
/// exportar, no aquí), sin `endPath`, o cuando ambos extremos no viven en
/// el mismo contenedor (nivel raíz, o misma celda de tabla).
List<DocumentTextPath> _extendedParagraphPaths(
  Document document,
  FieldAssignment assignment,
) {
  final endPath = assignment.endPath;
  if (assignment.isListField || endPath == null) {
    return const <DocumentTextPath>[];
  }

  final steps = assignment.path.steps;
  final endSteps = endPath.steps;
  if (steps.isEmpty || endSteps.isEmpty || steps.length != endSteps.length) {
    return const <DocumentTextPath>[];
  }
  final firstStep = steps.first;
  final endFirstStep = endSteps.first;
  if (firstStep is! RootDocumentBlockStep ||
      endFirstStep is! RootDocumentBlockStep) {
    return const <DocumentTextPath>[];
  }

  final bodyBlocks = <DocumentBlock>[
    for (final page in document.pages) ...page.blocks,
  ];

  if (steps.length == 1) {
    return _paragraphsBetween(
      blocks: bodyBlocks,
      startBlockIndex: firstStep.blockIndex,
      endBlockIndex: endFirstStep.blockIndex,
      pathForBlockIndex: (blockIndex) => DocumentTextPath(
        steps: <DocumentPathStep>[
          DocumentPathStep.rootBlock(blockIndex: blockIndex),
        ],
        region: assignment.path.region,
      ),
    );
  }

  // Prosa multi-párrafo dentro de una celda de tabla: sólo el caso común de
  // un único nivel de anidación (sin tablas dentro de tablas), y ambos
  // extremos deben apuntar a la misma tabla y celda.
  if (steps.length != 2 || firstStep.blockIndex != endFirstStep.blockIndex) {
    return const <DocumentTextPath>[];
  }
  if (firstStep.blockIndex < 0 || firstStep.blockIndex >= bodyBlocks.length) {
    return const <DocumentTextPath>[];
  }
  final tableBlock = bodyBlocks[firstStep.blockIndex];
  if (tableBlock is! DocumentTableBlock) {
    return const <DocumentTextPath>[];
  }
  final cellStep = steps[1];
  final endCellStep = endSteps[1];
  if (cellStep is! DocumentTableCellBlockStep ||
      endCellStep is! DocumentTableCellBlockStep ||
      cellStep.rowIndex != endCellStep.rowIndex ||
      cellStep.cellIndex != endCellStep.cellIndex) {
    return const <DocumentTextPath>[];
  }
  final rows = tableBlock.table.rows;
  if (cellStep.rowIndex < 0 || cellStep.rowIndex >= rows.length) {
    return const <DocumentTextPath>[];
  }
  final cells = rows[cellStep.rowIndex].cells;
  if (cellStep.cellIndex < 0 || cellStep.cellIndex >= cells.length) {
    return const <DocumentTextPath>[];
  }
  final cellBlocks = cells[cellStep.cellIndex].blocks;

  return _paragraphsBetween(
    blocks: cellBlocks,
    startBlockIndex: cellStep.blockIndex,
    endBlockIndex: endCellStep.blockIndex,
    pathForBlockIndex: (blockIndex) => DocumentTextPath(
      steps: <DocumentPathStep>[
        firstStep,
        DocumentPathStep.cellBlock(
          rowIndex: cellStep.rowIndex,
          cellIndex: cellStep.cellIndex,
          blockIndex: blockIndex,
        ),
      ],
      region: assignment.path.region,
    ),
  );
}

/// Paths of the paragraph blocks strictly between [startBlockIndex] and
/// [endBlockIndex] (exclusive on both ends) within [blocks], stopping early
/// at the first non-paragraph block or out-of-range index.
List<DocumentTextPath> _paragraphsBetween({
  required List<DocumentBlock> blocks,
  required int startBlockIndex,
  required int endBlockIndex,
  required DocumentTextPath Function(int blockIndex) pathForBlockIndex,
}) {
  final paths = <DocumentTextPath>[];
  for (
    var blockIndex = startBlockIndex + 1;
    blockIndex < endBlockIndex;
    blockIndex++
  ) {
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      break;
    }
    if (blocks[blockIndex] is! DocumentParagraphBlock) {
      break;
    }
    paths.add(pathForBlockIndex(blockIndex));
  }
  return paths;
}

/// Longitud total del texto plano de la [DocumentParagraph] en [path], para
/// resaltarla completa como párrafo extendido. `null` si [path] no resuelve
/// a un párrafo dentro de [document].
int? _paragraphTextLength(Document document, DocumentTextPath path) {
  try {
    final paragraph = resolveParagraph(document, path);
    return paragraph.runs.fold<int>(0, (sum, run) => sum + run.text.length);
  } on DocumentTextPathResolutionException {
    return null;
  }
}
