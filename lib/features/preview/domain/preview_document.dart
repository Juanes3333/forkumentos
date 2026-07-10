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
  final assignmentsByPath = groupBy<FieldAssignment, DocumentTextPath>(
    assignments,
    (assignment) => assignment.path,
  );

  return document.copyWith(
    pages: <DocumentPage>[
      for (var pageIndex = 0; pageIndex < document.pages.length; pageIndex++)
        _buildPreviewPage(
          document.pages[pageIndex],
          pageIndex: pageIndex,
          assignmentsByPath: assignmentsByPath,
          headers: headers,
          row: row,
        ),
    ],
  );
}

DocumentPage _buildPreviewPage(
  DocumentPage page, {
  required int pageIndex,
  required Map<DocumentTextPath, List<FieldAssignment>> assignmentsByPath,
  required List<String> headers,
  required List<String?> row,
}) {
  return page.copyWith(
    blocks: <DocumentBlock>[
      for (var blockIndex = 0; blockIndex < page.blocks.length; blockIndex++)
        _buildPreviewBlock(
          page.blocks[blockIndex],
          pageIndex: pageIndex,
          rootBlockIndex: blockIndex,
          prefixSteps: const <DocumentPathStep>[],
          assignmentsByPath: assignmentsByPath,
          headers: headers,
          row: row,
        ),
    ],
  );
}

DocumentBlock _buildPreviewBlock(
  DocumentBlock block, {
  required int pageIndex,
  required int rootBlockIndex,
  required List<DocumentPathStep> prefixSteps,
  required Map<DocumentTextPath, List<FieldAssignment>> assignmentsByPath,
  required List<String> headers,
  required List<String?> row,
}) {
  return switch (block) {
    DocumentParagraphBlock(:final paragraph) => DocumentBlock.paragraph(
      _buildPreviewParagraph(
        paragraph,
        path: DocumentTextPath(
          pageIndex: pageIndex,
          steps: <DocumentPathStep>[
            DocumentPathStep.rootBlock(blockIndex: rootBlockIndex),
            ...prefixSteps,
          ],
        ),
        assignmentsByPath: assignmentsByPath,
        headers: headers,
        row: row,
      ),
    ),
    DocumentTableBlock(:final table) => DocumentBlock.table(
      table.copyWith(
        rows: <DocumentTableRow>[
          for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
            table.rows[rowIndex].copyWith(
              cells: <DocumentTableCell>[
                for (
                  var cellIndex = 0;
                  cellIndex < table.rows[rowIndex].cells.length;
                  cellIndex++
                )
                  table.rows[rowIndex].cells[cellIndex].copyWith(
                    blocks: <DocumentBlock>[
                      for (
                        var blockIndex = 0;
                        blockIndex <
                            table.rows[rowIndex].cells[cellIndex].blocks.length;
                        blockIndex++
                      )
                        _buildPreviewBlock(
                          table
                              .rows[rowIndex]
                              .cells[cellIndex]
                              .blocks[blockIndex],
                          pageIndex: pageIndex,
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
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    ),
  };
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
    );

    final replacement = _replacementForAssignment(
      assignment,
      headers: headers,
      row: row,
    );
    final replacementStyle = _styleAtOffset(segments, start);
    previewRuns.add(replacementStyle.copyWith(text: replacement));
    cursor = end;
  }

  _appendOriginalSlice(
    previewRuns,
    segments: segments,
    start: cursor,
    end: plainText.length,
  );

  return DocumentParagraph(runs: _mergeAdjacentRuns(previewRuns));
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
}) {
  if (start >= end) {
    return;
  }

  for (final segment in segments) {
    if (segment.end <= start || segment.start >= end) {
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
    final hasSameStyle =
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
