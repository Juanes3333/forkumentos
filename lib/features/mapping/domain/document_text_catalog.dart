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

/// Where a global offset into the concatenated document text lands.
typedef _GlobalLocation = ({DocumentTextPath path, int localOffset});

/// Finds every occurrence of [needle] anywhere in [document], including
/// matches whose text spans two or more paragraphs (the needle contains a
/// literal `\n`). All paragraph texts are concatenated into one string
/// joined by `\n` — the same separator a caller uses to represent a
/// paragraph break in a copied selection — so `indexOf` can find matches
/// that cross a paragraph boundary. Each match's start/end global offset is
/// then mapped back to its owning paragraph; `endPath` is left `null` when
/// the match stays within a single paragraph (same contract as
/// [FieldAssignment.endPath]).
List<TextOccurrence> findExactTextOccurrences({
  required Document document,
  required String needle,
}) {
  final normalizedNeedle = needle.trim();
  if (normalizedNeedle.isEmpty) {
    return const <TextOccurrence>[];
  }

  final entries = enumerateParagraphTexts(document);
  if (entries.isEmpty) {
    return const <TextOccurrence>[];
  }

  final buffer = StringBuffer();
  final starts = List<int>.filled(entries.length, 0);
  for (var i = 0; i < entries.length; i++) {
    starts[i] = buffer.length;
    buffer.write(entries[i].text);
    if (i < entries.length - 1) {
      buffer.write('\n');
    }
  }
  final globalText = buffer.toString();

  _GlobalLocation locate(int globalOffset) {
    for (var i = 0; i < entries.length; i++) {
      final start = starts[i];
      final len = entries[i].text.length;
      if (globalOffset >= start && globalOffset <= start + len) {
        return (path: entries[i].path, localOffset: globalOffset - start);
      }
    }
    final last = entries.length - 1;
    return (path: entries[last].path, localOffset: entries[last].text.length);
  }

  // La normalización reemplaza carácter por carácter (comilla curva → recta),
  // así que los índices sobre el texto normalizado siguen siendo válidos sobre
  // `globalText` original.
  final normalizedGlobal = _normalizeForMatching(globalText);
  final normalizedSearch = _normalizeForMatching(normalizedNeedle);

  final occurrences = <TextOccurrence>[];
  var searchStart = 0;
  while (true) {
    final matchIndex = normalizedGlobal.indexOf(normalizedSearch, searchStart);
    if (matchIndex < 0) {
      break;
    }
    final matchEnd = matchIndex + normalizedSearch.length;

    var adjustedMatchIndex = matchIndex;
    var adjustedMatchEnd = matchEnd;

    // Si el match está rodeado por comillas en el documento, ampliar para
    // incluirlas: así el reemplazo al exportar borra también las comillas.
    if (adjustedMatchIndex > 0 && adjustedMatchEnd < globalText.length) {
      final charBefore = globalText[adjustedMatchIndex - 1];
      final charAfter = globalText[adjustedMatchEnd];
      if (_isQuote(charBefore) && _isQuote(charAfter)) {
        adjustedMatchIndex -= 1;
        adjustedMatchEnd += 1;
      }
    }

    final start = locate(adjustedMatchIndex);
    final end = locate(adjustedMatchEnd);

    occurrences.add(
      TextOccurrence(
        path: start.path,
        startOffset: start.localOffset,
        endOffset: end.localOffset,
        matchedText: normalizedNeedle,
        endPath: start.path == end.path ? null : end.path,
      ),
    );
    searchStart = matchEnd;
  }

  return occurrences;
}

/// Normaliza un texto para comparación de automapeo: reemplaza comillas
/// tipográficas/especiales por comillas rectas para que un valor del Excel
/// escrito con comillas rectas coincida aunque el DOCX use comillas curvas.
///
/// ponytail: deliberadamente NO baja a minúsculas. Hacerlo convierte valores
/// cortos ('A', 'Ana') en subcadenas de texto no relacionado ('Juan',
/// 'ana@correo.com') y el automapeo empieza a reclamar tramos ajenos.
String _normalizeForMatching(String text) {
  return text
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('«', '"')
      .replaceAll('»', '"');
}

bool _isQuote(String char) {
  return const {
    '"',
    "'",
    '“',
    '”',
    '‘',
    '’',
    '«',
    '»',
  }.contains(char);
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
