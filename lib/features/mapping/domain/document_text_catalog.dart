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

  // Absolute, page-agnostic counter: advances once per top-level block across
  // the WHOLE document regardless of which heuristic `DocumentPage` it landed
  // on, so it can never disagree with the exporter's identical document-order
  // count (see the DocumentTextPath doc comment).
  var rootBlockIndex = 0;
  for (final page in document.pages) {
    for (final block in page.blocks) {
      _collectParagraphTexts(
        rootBlockIndex: rootBlockIndex,
        block: block,
        entries: entries,
      );
      rootBlockIndex++;
    }
  }

  _collectRegionParagraphTexts(
    blocks: document.header,
    region: DocumentTextRegion.header,
    entries: entries,
  );
  _collectRegionParagraphTexts(
    blocks: document.footer,
    region: DocumentTextRegion.footer,
    entries: entries,
  );

  return entries;
}

void _collectRegionParagraphTexts({
  required List<DocumentBlock> blocks,
  required DocumentTextRegion region,
  required List<ParagraphTextEntry> entries,
}) {
  for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
    _collectParagraphTexts(
      rootBlockIndex: blockIndex,
      block: blocks[blockIndex],
      entries: entries,
      region: region,
    );
  }
}

List<ParagraphTextEntry> extractDocumentTextPlaceholders(Document document) {
  return enumerateParagraphTexts(
    document,
  ).where((entry) => entry.text.trim().isNotEmpty).toList();
}

void _collectParagraphTexts({
  required int rootBlockIndex,
  required DocumentBlock block,
  required List<ParagraphTextEntry> entries,
  List<DocumentPathStep> prefixSteps = const <DocumentPathStep>[],
  DocumentTextRegion region = DocumentTextRegion.body,
}) {
  switch (block) {
    case DocumentParagraphBlock(:final paragraph):
      entries.add(
        ParagraphTextEntry(
          path: DocumentTextPath(
            steps: <DocumentPathStep>[
              DocumentPathStep.rootBlock(blockIndex: rootBlockIndex),
              ...prefixSteps,
            ],
            region: region,
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
              rootBlockIndex: rootBlockIndex,
              block: cell.blocks[innerBlockIndex],
              entries: entries,
              region: region,
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
    if (assignment.path != path) {
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

bool occurrencesMatch({
  required TextOccurrence occurrence,
  required DocumentTextPath path,
  required int startOffset,
  required int endOffset,
}) {
  return occurrence.path == path &&
      occurrence.startOffset == startOffset &&
      occurrence.endOffset == endOffset;
}
