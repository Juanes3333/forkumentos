import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:xml/xml.dart';

/// One resolved text replacement for a DOCX paragraph path.
final class DocxTextReplacement {
  const DocxTextReplacement({
    required this.pageIndex,
    required this.steps,
    required this.startOffset,
    required this.endOffset,
    required this.text,
  });

  final int pageIndex;
  final List<ExportPathStep> steps;
  final int startOffset;
  final int endOffset;
  final String text;
}

/// Decoded DOCX ZIP entries ready for per-row XML mutation without re-decode.
final class PreparedDocxTemplate {
  const PreparedDocxTemplate({required this.entries});

  final List<PreparedDocxEntry> entries;
}

final class PreparedDocxEntry {
  const PreparedDocxEntry({
    required this.name,
    required this.bytes,
    required this.compress,
  });

  final String name;
  final Uint8List bytes;
  final bool compress;
}

/// Mutates a template DOCX ZIP: replaces mapped text in `word/document.xml`
/// (paragraphs + tables) and copies every other entry intact.
final class DocxZipExporter {
  const DocxZipExporter();

  /// Decodes [templateBytes] once; reuse with [applyPrepared] per row.
  PreparedDocxTemplate prepare(Uint8List templateBytes) {
    final archive = _decodeArchive(templateBytes);
    final entries = <PreparedDocxEntry>[];
    var hasDocumentXml = false;

    for (final file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final content = file.content;
      // Always copy: archive buffers must not be aliased across Isolate.run /
      // ZipEncoder mutations when the same prepared template is reused.
      final bytes = Uint8List.fromList(content as List<int>);
      if (file.name.toLowerCase() == 'word/document.xml') {
        hasDocumentXml = true;
      }
      entries.add(
        PreparedDocxEntry(
          name: file.name,
          bytes: bytes,
          compress: file.compress,
        ),
      );
    }

    if (!hasDocumentXml) {
      throw const FormatException('El DOCX no contiene word/document.xml.');
    }

    return PreparedDocxTemplate(entries: entries);
  }

  /// Applies [replacements] to a [PreparedDocxTemplate] and returns a new ZIP.
  Uint8List applyPrepared({
    required PreparedDocxTemplate prepared,
    required List<DocxTextReplacement> replacements,
  }) {
    final output = Archive();

    for (final entry in prepared.entries) {
      if (entry.name.toLowerCase() == 'word/document.xml') {
        final xml = utf8.decode(entry.bytes, allowMalformed: true);
        final updated = _applyToDocumentXml(xml, replacements);
        final encoded = Uint8List.fromList(utf8.encode(updated));
        output.addFile(
          ArchiveFile(entry.name, encoded.length, encoded)
            ..compress = entry.compress,
        );
        continue;
      }

      // ponytail: headers/footers copied intact — mapping into headers is not
      // in the Document model yet; wire ExportPlaceholder paths when it is.
      final copied = Uint8List.fromList(entry.bytes);
      output.addFile(
        ArchiveFile(entry.name, copied.length, copied)
          ..compress = entry.compress,
      );
    }

    final encoded = ZipEncoder().encode(output);
    if (encoded == null) {
      throw const FormatException('No se pudo codificar el DOCX exportado.');
    }
    return Uint8List.fromList(encoded);
  }

  /// Applies [replacements] to [templateBytes] and returns a new DOCX ZIP.
  Uint8List applyReplacements({
    required Uint8List templateBytes,
    required List<DocxTextReplacement> replacements,
  }) {
    return applyPrepared(
      prepared: prepare(templateBytes),
      replacements: replacements,
    );
  }
}

Archive _decodeArchive(Uint8List bytes) {
  try {
    return ZipDecoder().decodeBytes(bytes, verify: true);
  } catch (_) {
    throw const FormatException('El archivo no es un documento DOCX válido.');
  }
}

String _applyToDocumentXml(
  String xmlContent,
  List<DocxTextReplacement> replacements,
) {
  if (replacements.isEmpty) {
    return xmlContent;
  }

  final document = XmlDocument.parse(xmlContent);
  final body = _findBody(document);
  final byPath = <String, List<DocxTextReplacement>>{};
  for (final replacement in replacements) {
    final key = _pathKey(replacement.pageIndex, replacement.steps);
    (byPath[key] ??= <DocxTextReplacement>[]).add(replacement);
  }

  var pageIndex = 0;
  var blockIndexOnPage = 0;

  for (final child in body.childElements.toList()) {
    final localName = child.name.local;
    if (localName == 'p') {
      final chunks = _splitParagraphChunks(child);
      for (final chunk in chunks) {
        final steps = <ExportPathStep>[
          ExportPathStep.rootBlock(blockIndex: blockIndexOnPage),
        ];
        final key = _pathKey(pageIndex, steps);
        final pathReplacements = byPath[key];
        if (pathReplacements != null && pathReplacements.isNotEmpty) {
          _applyToTextNodes(chunk.nodes, pathReplacements);
        }
        blockIndexOnPage++;
        if (chunk.endsWithPageBreak) {
          pageIndex++;
          blockIndexOnPage = 0;
        }
      }
      continue;
    }

    if (localName == 'tbl') {
      _walkTable(
        child,
        pageIndex: pageIndex,
        rootBlockIndex: blockIndexOnPage,
        byPath: byPath,
      );
      blockIndexOnPage++;
    }
  }

  return document.toXmlString();
}

void _walkTable(
  XmlElement table, {
  required int pageIndex,
  required int rootBlockIndex,
  required Map<String, List<DocxTextReplacement>> byPath,
}) {
  var rowIndex = 0;
  for (final row in table.childElements) {
    if (row.name.local != 'tr') {
      continue;
    }
    var cellIndex = 0;
    for (final cell in row.childElements) {
      if (cell.name.local != 'tc') {
        continue;
      }
      var innerBlockIndex = 0;
      for (final child in cell.childElements) {
        if (child.name.local != 'p') {
          if (child.name.local == 'tbl') {
            innerBlockIndex++;
          }
          continue;
        }
        final chunks = _splitParagraphChunks(child);
        for (final chunk in chunks) {
          final steps = <ExportPathStep>[
            ExportPathStep.rootBlock(blockIndex: rootBlockIndex),
            ExportPathStep.cellBlock(
              rowIndex: rowIndex,
              cellIndex: cellIndex,
              blockIndex: innerBlockIndex,
            ),
          ];
          final key = _pathKey(pageIndex, steps);
          final pathReplacements = byPath[key];
          if (pathReplacements != null && pathReplacements.isNotEmpty) {
            _applyToTextNodes(chunk.nodes, pathReplacements);
          }
          innerBlockIndex++;
        }
      }
      cellIndex++;
    }
    rowIndex++;
  }
}

void _applyToTextNodes(
  List<_TextNodeRef> nodes,
  List<DocxTextReplacement> replacements,
) {
  if (nodes.isEmpty) {
    return;
  }

  final plain = nodes.map((node) => node.text).join();
  final sorted = [...replacements]
    ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

  final output = StringBuffer();
  var cursor = 0;
  for (final replacement in sorted) {
    final start = replacement.startOffset.clamp(0, plain.length);
    final end = replacement.endOffset.clamp(0, plain.length);
    if (start < cursor || start >= end) {
      continue;
    }
    output
      ..write(plain.substring(cursor, start))
      ..write(replacement.text);
    cursor = end;
  }
  output.write(plain.substring(cursor));
  final merged = output.toString();

  // ponytail: put all replaced plain text into the first w:t and clear the
  // rest. Ceiling: run-level style fidelity across a replacement span; upgrade
  // by splitting text back across original nodes when styles must survive.
  nodes.first.element.innerText = merged;
  for (final node in nodes.skip(1)) {
    node.element.innerText = '';
  }
}

XmlElement _findBody(XmlDocument document) {
  for (final element in document.descendants.whereType<XmlElement>()) {
    if (element.name.local == 'body') {
      return element;
    }
  }
  throw const FormatException(
    'El archivo word/document.xml no es un XML válido.',
  );
}

String _pathKey(int pageIndex, List<ExportPathStep> steps) {
  final buffer = StringBuffer('$pageIndex');
  for (final step in steps) {
    switch (step) {
      case ExportRootBlockStep(:final blockIndex):
        buffer.write('|r$blockIndex');
      case ExportCellBlockStep(
        :final rowIndex,
        :final cellIndex,
        :final blockIndex,
      ):
        buffer.write('|c$rowIndex.$cellIndex.$blockIndex');
    }
  }
  return buffer.toString();
}

List<_ParagraphChunkNodes> _splitParagraphChunks(XmlElement paragraph) {
  final chunks = <_ParagraphChunkNodes>[];
  var current = <_TextNodeRef>[];
  var sawVisible = false;
  var endedWithPageBreak = false;

  final runs = paragraph.descendants.whereType<XmlElement>().where(
    (element) => element.name.local == 'r',
  );

  for (final run in runs) {
    if (_hasTrackedChangeAncestor(run)) {
      continue;
    }
    if (_isHiddenRun(run)) {
      continue;
    }

    for (final element in run.descendants.whereType<XmlElement>()) {
      final localName = element.name.local;
      if (localName == 't') {
        current.add(_TextNodeRef(element: element, text: element.innerText));
        sawVisible = true;
        endedWithPageBreak = false;
        continue;
      }
      if (localName == 'tab') {
        // Tabs contribute '\t' to plain text in the Document model but are not
        // editable w:t nodes; offsets still align for typical mapped spans.
        sawVisible = true;
        endedWithPageBreak = false;
        continue;
      }
      if (localName == 'br') {
        if (_isPageBreak(element)) {
          chunks.add(
            _ParagraphChunkNodes(nodes: current, endsWithPageBreak: true),
          );
          current = <_TextNodeRef>[];
          sawVisible = true;
          endedWithPageBreak = true;
        } else {
          sawVisible = true;
          endedWithPageBreak = false;
        }
        continue;
      }
      if (localName == 'lastRenderedPageBreak') {
        chunks.add(
          _ParagraphChunkNodes(nodes: current, endsWithPageBreak: true),
        );
        current = <_TextNodeRef>[];
        sawVisible = true;
        endedWithPageBreak = true;
      }
    }
  }

  if (!sawVisible) {
    return <_ParagraphChunkNodes>[
      const _ParagraphChunkNodes(
        nodes: <_TextNodeRef>[],
        endsWithPageBreak: false,
      ),
    ];
  }

  if (!endedWithPageBreak || current.isNotEmpty) {
    chunks.add(_ParagraphChunkNodes(nodes: current, endsWithPageBreak: false));
  }

  return chunks;
}

bool _hasTrackedChangeAncestor(XmlElement run) {
  for (final ancestor in run.ancestors.whereType<XmlElement>()) {
    final localName = ancestor.name.local;
    if (localName == 'ins' || localName == 'del') {
      return true;
    }
  }
  return false;
}

bool _isHiddenRun(XmlElement run) {
  for (final child in run.childElements) {
    if (child.name.local != 'rPr') {
      continue;
    }
    for (final property in child.childElements) {
      if (property.name.local == 'vanish') {
        return true;
      }
    }
  }
  return false;
}

bool _isPageBreak(XmlElement breakElement) {
  for (final attribute in breakElement.attributes) {
    if (attribute.name.local == 'type') {
      return attribute.value == 'page';
    }
  }
  return false;
}

final class _TextNodeRef {
  const _TextNodeRef({required this.element, required this.text});

  final XmlElement element;
  final String text;
}

final class _ParagraphChunkNodes {
  const _ParagraphChunkNodes({
    required this.nodes,
    required this.endsWithPageBreak,
  });

  final List<_TextNodeRef> nodes;
  final bool endsWithPageBreak;
}
