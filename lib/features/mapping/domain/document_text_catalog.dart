import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/text_occurrence.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

final class ParagraphTextEntry {
  const ParagraphTextEntry({required this.path, required this.text});

  final DocumentTextPath path;
  final String text;
}

List<ParagraphTextEntry> enumerateParagraphTexts(Document document) {
  final entries = <ParagraphTextEntry>[];

  for (var pageIndex = 0; pageIndex < document.pages.length; pageIndex++) {
    final page = document.pages[pageIndex];
    for (var blockIndex = 0; blockIndex < page.blocks.length; blockIndex++) {
      _collectParagraphTexts(
        pageIndex: pageIndex,
        rootBlockIndex: blockIndex,
        block: page.blocks[blockIndex],
        entries: entries,
      );
    }
  }

  return entries;
}

List<ParagraphTextEntry> extractDocumentTextPlaceholders(Document document) {
  return enumerateParagraphTexts(
    document,
  ).where((entry) => entry.text.trim().isNotEmpty).toList();
}

void _collectParagraphTexts({
  required int pageIndex,
  required int rootBlockIndex,
  required DocumentBlock block,
  required List<ParagraphTextEntry> entries,
  List<DocumentPathStep> prefixSteps = const <DocumentPathStep>[],
}) {
  switch (block) {
    case DocumentParagraphBlock(:final paragraph):
      entries.add(
        ParagraphTextEntry(
          path: DocumentTextPath(
            pageIndex: pageIndex,
            steps: <DocumentPathStep>[
              DocumentPathStep.rootBlock(blockIndex: rootBlockIndex),
              ...prefixSteps,
            ],
          ),
          text: paragraphPlainText(paragraph),
        ),
      );
    case DocumentTableBlock(:final table):
      for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++) {
        final row = table.rows[rowIndex];
        for (var cellIndex = 0; cellIndex < row.cells.length; cellIndex++) {
          final cell = row.cells[cellIndex];
          for (
            var innerBlockIndex = 0;
            innerBlockIndex < cell.blocks.length;
            innerBlockIndex++
          ) {
            _collectParagraphTexts(
              pageIndex: pageIndex,
              rootBlockIndex: rootBlockIndex,
              block: cell.blocks[innerBlockIndex],
              entries: entries,
              prefixSteps: <DocumentPathStep>[
                ...prefixSteps,
                DocumentPathStep.cellBlock(
                  rowIndex: rowIndex,
                  cellIndex: cellIndex,
                  blockIndex: innerBlockIndex,
                ),
              ],
            );
          }
        }
      }
  }
}

String paragraphPlainText(DocumentParagraph paragraph) {
  return paragraph.runs.map((run) => run.text).join();
}

List<TextOccurrence> findExactTextOccurrences({
  required Document document,
  required String needle,
}) {
  final normalizedNeedle = needle.trim();
  if (normalizedNeedle.isEmpty) {
    return const <TextOccurrence>[];
  }

  final occurrences = <TextOccurrence>[];
  for (final entry in enumerateParagraphTexts(document)) {
    var searchStart = 0;
    while (true) {
      final matchIndex = entry.text.indexOf(normalizedNeedle, searchStart);
      if (matchIndex < 0) {
        break;
      }

      occurrences.add(
        TextOccurrence(
          path: entry.path,
          startOffset: matchIndex,
          endOffset: matchIndex + normalizedNeedle.length,
          matchedText: normalizedNeedle,
        ),
      );
      searchStart = matchIndex + normalizedNeedle.length;
    }
  }

  return occurrences;
}

FieldAssignment? findOverlappingAssignment({
  required List<FieldAssignment> assignments,
  required DocumentTextPath path,
  required int startOffset,
  required int endOffset,
}) {
  for (final assignment in assignments) {
    if (!_pathsEqual(assignment.path, path)) {
      continue;
    }

    final overlaps =
        startOffset < assignment.endOffset &&
        endOffset > assignment.startOffset;
    if (overlaps) {
      return assignment;
    }
  }

  return null;
}

bool _pathsEqual(DocumentTextPath left, DocumentTextPath right) {
  if (left.pageIndex != right.pageIndex ||
      left.steps.length != right.steps.length) {
    return false;
  }

  for (var index = 0; index < left.steps.length; index++) {
    final leftStep = left.steps[index];
    final rightStep = right.steps[index];
    if (leftStep.runtimeType != rightStep.runtimeType) {
      return false;
    }

    if (leftStep is RootDocumentBlockStep &&
        rightStep is RootDocumentBlockStep) {
      if (leftStep.blockIndex != rightStep.blockIndex) {
        return false;
      }
      continue;
    }

    if (leftStep is DocumentTableCellBlockStep &&
        rightStep is DocumentTableCellBlockStep) {
      if (leftStep.rowIndex != rightStep.rowIndex ||
          leftStep.cellIndex != rightStep.cellIndex ||
          leftStep.blockIndex != rightStep.blockIndex) {
        return false;
      }
      continue;
    }

    return false;
  }

  return true;
}

bool occurrencesMatch({
  required TextOccurrence occurrence,
  required DocumentTextPath path,
  required int startOffset,
  required int endOffset,
}) {
  return _pathsEqual(occurrence.path, path) &&
      occurrence.startOffset == startOffset &&
      occurrence.endOffset == endOffset;
}
