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
    if (assignment.path == path) {
      final color = mappingColorForFieldIndex(assignment.fieldIndex);
      final emphasize =
          emphasizedAssignmentId == assignment.id ||
          hoveredFieldIndex == assignment.fieldIndex;
      highlights.add(
        ParagraphHighlightSegment(
          startOffset: assignment.startOffset,
          endOffset: assignment.endOffset,
          color: color,
          emphasize: emphasize,
        ),
      );
      continue;
    }

    if (document == null) {
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
        color: mappingColorForFieldIndex(assignment.fieldIndex),
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

/// Rutas de los `assignment.paragraphSpan - 1` párrafos que siguen al
/// mapeado, para pintarlos como extensión de campo prosa multi-párrafo.
/// Espeja el criterio de `_collectListGroup` en `docx_zip_exporter.dart`: se
/// detiene en el primer bloque que no sea un párrafo (p. ej. una tabla) o al
/// llegar al final del contenedor. Vacío para campos de lista numerada
/// (esos se auto-detectan por numId al exportar, no aquí) o sin span.
List<DocumentTextPath> _extendedParagraphPaths(
  Document document,
  FieldAssignment assignment,
) {
  final span = assignment.paragraphSpan;
  if (assignment.isListField || span == null || span <= 1) {
    return const <DocumentTextPath>[];
  }

  final steps = assignment.path.steps;
  if (steps.isEmpty) {
    return const <DocumentTextPath>[];
  }
  final firstStep = steps.first;
  if (firstStep is! RootDocumentBlockStep) {
    return const <DocumentTextPath>[];
  }

  final bodyBlocks = <DocumentBlock>[
    for (final page in document.pages) ...page.blocks,
  ];

  if (steps.length == 1) {
    final paths = <DocumentTextPath>[];
    for (var offset = 1; offset < span; offset++) {
      final blockIndex = firstStep.blockIndex + offset;
      if (blockIndex < 0 || blockIndex >= bodyBlocks.length) {
        break;
      }
      if (bodyBlocks[blockIndex] is! DocumentParagraphBlock) {
        break;
      }
      paths.add(
        DocumentTextPath(
          steps: <DocumentPathStep>[
            DocumentPathStep.rootBlock(blockIndex: blockIndex),
          ],
          region: assignment.path.region,
        ),
      );
    }
    return paths;
  }

  // Prosa multi-párrafo dentro de una celda de tabla: sólo el caso común de
  // un único nivel de anidación (sin tablas dentro de tablas).
  if (steps.length != 2) {
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
  if (cellStep is! DocumentTableCellBlockStep) {
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

  final paths = <DocumentTextPath>[];
  for (var offset = 1; offset < span; offset++) {
    final blockIndex = cellStep.blockIndex + offset;
    if (blockIndex < 0 || blockIndex >= cellBlocks.length) {
      break;
    }
    if (cellBlocks[blockIndex] is! DocumentParagraphBlock) {
      break;
    }
    paths.add(
      DocumentTextPath(
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
