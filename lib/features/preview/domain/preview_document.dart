import 'package:collection/collection.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

Document buildPreviewDocument({
  required Document document,
  required List<FieldAssignment> assignments,
  required List<String> headers,
  required List<String?> row,
}) {
  if (assignments.isEmpty) {
    return document;
  }

  final assignmentsByPath = groupBy<FieldAssignment, DocumentTextPath>(
    assignments,
    (assignment) => assignment.path,
  );

  // Page boundaries only decide which page a rebuilt block lands back on;
  // matching itself is by absolute rootBlockIndex (see the DocumentTextPath
  // doc comment), so this walks a running document-order offset instead of
  // an index into `document.pages`.
  var anyPageChanged = false;
  var rootBlockIndex = 0;
  final pages = List<DocumentPage>.generate(document.pages.length, (pageIndex) {
    final original = document.pages[pageIndex];
    final built = _buildPreviewPage(
      original,
      pageStartIndex: rootBlockIndex,
      assignmentsByPath: assignmentsByPath,
      headers: headers,
      row: row,
    );
    rootBlockIndex += original.blocks.length;
    if (!identical(built, original)) {
      anyPageChanged = true;
    }
    return built;
  }, growable: false);

  if (!anyPageChanged) {
    return document;
  }

  return document.copyWith(pages: pages);
}

DocumentPage _buildPreviewPage(
  DocumentPage page, {
  required int pageStartIndex,
  required Map<DocumentTextPath, List<FieldAssignment>> assignmentsByPath,
  required List<String> headers,
  required List<String?> row,
}) {
  final pageEndIndex = pageStartIndex + page.blocks.length;
  final rootBlockIndexes = <int>{};
  for (final path in assignmentsByPath.keys) {
    if (path.steps.isEmpty) {
      continue;
    }
    final first = path.steps.first;
    if (first is RootDocumentBlockStep &&
        first.blockIndex >= pageStartIndex &&
        first.blockIndex < pageEndIndex) {
      rootBlockIndexes.add(first.blockIndex);
    }
  }

  if (rootBlockIndexes.isEmpty) {
    return page;
  }

  var anyBlockChanged = false;
  final blocks = List<DocumentBlock>.generate(page.blocks.length, (localIndex) {
    final absoluteIndex = pageStartIndex + localIndex;
    final original = page.blocks[localIndex];
    if (!rootBlockIndexes.contains(absoluteIndex)) {
      return original;
    }

    final built = _buildPreviewBlock(
      original,
      rootBlockIndex: absoluteIndex,
      prefixSteps: const <DocumentPathStep>[],
      assignmentsByPath: assignmentsByPath,
      headers: headers,
      row: row,
    );
    if (!identical(built, original)) {
      anyBlockChanged = true;
    }
    return built;
  }, growable: false);

  if (!anyBlockChanged) {
    return page;
  }

  return page.copyWith(blocks: blocks);
}

DocumentBlock _buildPreviewBlock(
  DocumentBlock block, {
  required int rootBlockIndex,
  required List<DocumentPathStep> prefixSteps,
  required Map<DocumentTextPath, List<FieldAssignment>> assignmentsByPath,
  required List<String> headers,
  required List<String?> row,
}) {
  return switch (block) {
    DocumentParagraphBlock(:final paragraph) => () {
      final path = DocumentTextPath(
        steps: <DocumentPathStep>[
          DocumentPathStep.rootBlock(blockIndex: rootBlockIndex),
          ...prefixSteps,
        ],
      );
      final built = _buildPreviewParagraph(
        paragraph,
        path: path,
        assignmentsByPath: assignmentsByPath,
        headers: headers,
        row: row,
      );
      if (identical(built, paragraph)) {
        return block;
      }
      return DocumentBlock.paragraph(built);
    }(),
    DocumentTableBlock(:final table) => _buildPreviewTableBlock(
      block,
      table: table,
      rootBlockIndex: rootBlockIndex,
      assignmentsByPath: assignmentsByPath,
      headers: headers,
      row: row,
    ),
  };
}

DocumentBlock _buildPreviewTableBlock(
  DocumentBlock original, {
  required DocumentTable table,
  required int rootBlockIndex,
  required Map<DocumentTextPath, List<FieldAssignment>> assignmentsByPath,
  required List<String> headers,
  required List<String?> row,
}) {
  var anyRowChanged = false;
  final rows = List<DocumentTableRow>.generate(table.rows.length, (rowIndex) {
    final originalRow = table.rows[rowIndex];
    var anyCellChanged = false;
    final cells = List<DocumentTableCell>.generate(originalRow.cells.length, (
      cellIndex,
    ) {
      final originalCell = originalRow.cells[cellIndex];
      var anyNestedChanged = false;
      final nestedBlocks = List<DocumentBlock>.generate(
        originalCell.blocks.length,
        (blockIndex) {
          final originalBlock = originalCell.blocks[blockIndex];
          final path = DocumentTextPath(
            steps: <DocumentPathStep>[
              DocumentPathStep.rootBlock(blockIndex: rootBlockIndex),
              DocumentPathStep.cellBlock(
                rowIndex: rowIndex,
                cellIndex: cellIndex,
                blockIndex: blockIndex,
              ),
            ],
          );
          if (!assignmentsByPath.containsKey(path)) {
            return originalBlock;
          }

          final built = _buildPreviewBlock(
            originalBlock,
            rootBlockIndex: rootBlockIndex,
            prefixSteps: <DocumentPathStep>[
              DocumentPathStep.cellBlock(
                rowIndex: rowIndex,
                cellIndex: cellIndex,
                blockIndex: blockIndex,
              ),
            ],
            assignmentsByPath: assignmentsByPath,
            headers: headers,
            row: row,
          );
          if (!identical(built, originalBlock)) {
            anyNestedChanged = true;
          }
          return built;
        },
        growable: false,
      );

      if (!anyNestedChanged) {
        return originalCell;
      }
      anyCellChanged = true;
      return originalCell.copyWith(blocks: nestedBlocks);
    }, growable: false);

    if (!anyCellChanged) {
      return originalRow;
    }
    anyRowChanged = true;
    return originalRow.copyWith(cells: cells);
  }, growable: false);

  if (!anyRowChanged) {
    return original;
  }

  return DocumentBlock.table(table.copyWith(rows: rows));
}

DocumentParagraph _buildPreviewParagraph(
  DocumentParagraph paragraph, {
  required DocumentTextPath path,
  required Map<DocumentTextPath, List<FieldAssignment>> assignmentsByPath,
  required List<String> headers,
  required List<String?> row,
}) {
  final paragraphAssignments = (assignmentsByPath[path] ?? <FieldAssignment>[])
    ..sort((left, right) => left.startOffset.compareTo(right.startOffset));
  if (paragraphAssignments.isEmpty) {
    return paragraph;
  }

  final plainText = paragraph.runs.map((run) => run.text).join();
  final segments = _segmentRuns(paragraph.runs);
  final previewRuns = <DocumentRun>[];
  // Los runs de imagen no ocupan texto, así que ningún tramo los "contiene":
  // se emiten al cruzar su posición y se anotan aquí para no duplicarlos
  // cuando esa posición coincide con el límite de dos tramos.
  final emittedImages = <int>{};
  var cursor = 0;

  for (final assignment in paragraphAssignments) {
    final start = assignment.startOffset.clamp(0, plainText.length);
    final end = assignment.endOffset.clamp(0, plainText.length);
    if (start < cursor || start >= end) {
      continue;
    }

    _appendOriginalSlice(
      previewRuns,
      segments: segments,
      start: cursor,
      end: start,
      emittedImages: emittedImages,
    );

    final replacement = _replacementForAssignment(
      assignment,
      headers: headers,
      row: row,
    );
    final replacementStyle = _styleAtOffset(segments, start);
    previewRuns.add(replacementStyle.copyWith(text: replacement, image: null));
    cursor = end;
  }

  _appendOriginalSlice(
    previewRuns,
    segments: segments,
    start: cursor,
    end: plainText.length,
    emittedImages: emittedImages,
  );

  return paragraph.copyWith(runs: _mergeAdjacentRuns(previewRuns));
}

String _replacementForAssignment(
  FieldAssignment assignment, {
  required List<String> headers,
  required List<String?> row,
}) {
  if (assignment.fieldIndex < 0 || assignment.fieldIndex >= headers.length) {
    return '';
  }
  if (assignment.fieldIndex < 0 || assignment.fieldIndex >= row.length) {
    return '';
  }
  return row[assignment.fieldIndex] ?? '';
}

List<_RunSegment> _segmentRuns(List<DocumentRun> runs) {
  final segments = <_RunSegment>[];
  var cursor = 0;
  for (final run in runs) {
    final next = cursor + run.text.length;
    segments.add(_RunSegment(run: run, start: cursor, end: next));
    cursor = next;
  }
  return segments;
}

DocumentRun _styleAtOffset(List<_RunSegment> segments, int offset) {
  for (final segment in segments) {
    if (offset >= segment.start && offset < segment.end) {
      return segment.run;
    }
  }
  return segments.isEmpty
      ? const DocumentRun(
          text: '',
          isBold: false,
          isItalic: false,
          isUnderlined: false,
        )
      : segments.last.run;
}

void _appendOriginalSlice(
  List<DocumentRun> output, {
  required List<_RunSegment> segments,
  required int start,
  required int end,
  required Set<int> emittedImages,
}) {
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];

    if (segment.run.image != null) {
      if (segment.start >= start &&
          segment.start <= end &&
          emittedImages.add(index)) {
        output.add(segment.run);
      }
      continue;
    }

    if (start >= end || segment.end <= start || segment.start >= end) {
      continue;
    }

    final localStart = start > segment.start ? start - segment.start : 0;
    final localEnd = end < segment.end
        ? end - segment.start
        : segment.run.text.length;
    final text = segment.run.text.substring(localStart, localEnd);
    if (text.isEmpty) {
      continue;
    }
    output.add(segment.run.copyWith(text: text));
  }
}

List<DocumentRun> _mergeAdjacentRuns(List<DocumentRun> runs) {
  if (runs.isEmpty) {
    return runs;
  }

  final merged = <DocumentRun>[runs.first];
  for (final run in runs.skip(1)) {
    final previous = merged.last;
    // Una imagen nunca se funde con el texto vecino: su run existe para
    // marcar una posición en el flujo, no para aportar caracteres.
    final hasSameStyle =
        previous.image == null &&
        run.image == null &&
        previous.isBold == run.isBold &&
        previous.isItalic == run.isItalic &&
        previous.isUnderlined == run.isUnderlined;
    if (hasSameStyle) {
      merged[merged.length - 1] = previous.copyWith(
        text: '${previous.text}${run.text}',
      );
      continue;
    }
    merged.add(run);
  }
  return merged;
}

final class _RunSegment {
  const _RunSegment({
    required this.run,
    required this.start,
    required this.end,
  });

  final DocumentRun run;
  final int start;
  final int end;
}
