import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:xml/xml.dart';

/// One resolved text replacement for a DOCX paragraph path.
final class DocxTextReplacement {
  const DocxTextReplacement({
    required this.steps,
    required this.startOffset,
    required this.endOffset,
    required this.text,
  });

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
    // Sin reemplazos no se reescribe una sola letra, así que la copia es
    // idéntica a la plantilla y sus `lastRenderedPageBreak` siguen siendo
    // ciertos: no hay nada obsoleto que limpiar y se evita parsear y
    // reserializar el XML en cada fila.
    return xmlContent;
  }

  final document = XmlDocument.parse(xmlContent);
  final body = _findBody(document);
  final byPath = <String, List<DocxTextReplacement>>{};
  for (final replacement in replacements) {
    final key = _pathKey(replacement.steps);
    (byPath[key] ??= <DocxTextReplacement>[]).add(replacement);
  }

  // Absoluto y monotónico, en orden de documento: espejo exacto de
  // `enumerateParagraphTexts` (un incremento por segmento de
  // `_parseContainerBlocks`, incluidos los chunks en los que un párrafo se
  // divide por salto de página). Nada lo reinicia porque nada aguas abajo
  // necesita saber en qué página cae un bloque.
  var blockIndex = 0;

  for (final child in body.childElements.toList()) {
    final localName = child.name.local;
    if (localName == 'p') {
      final chunks = _splitParagraphChunks(child);
      for (final chunk in chunks) {
        final steps = <ExportPathStep>[
          ExportPathStep.rootBlock(blockIndex: blockIndex),
        ];
        final key = _pathKey(steps);
        final pathReplacements = byPath[key];
        if (pathReplacements != null && pathReplacements.isNotEmpty) {
          _applyToTextNodes(chunk.nodes, pathReplacements);
        }
        blockIndex++;
      }
      continue;
    }

    if (localName == 'tbl') {
      _walkTable(child, rootBlockIndex: blockIndex, byPath: byPath);
      blockIndex++;
    }
  }

  _stripLastRenderedPageBreaks(document);
  return document.toXmlString();
}

/// Borra todo `w:lastRenderedPageBreak` del documento exportado.
///
/// Se ejecuta DESPUÉS del recorrido de reemplazos, nunca antes: esos
/// marcadores definen los límites de chunk contra los que se calcularon las
/// claves de ruta, así que quitarlos primero movería el destino de cada
/// reemplazo.
///
/// Al exportar reescribimos el texto sin que Word rehaga el maquetado, así
/// que cada marcador queda obsoleto en cuanto tocamos el párrafo: describe un
/// corte de página que ya no existe. Dejarlos convertía un documento de 11
/// páginas en uno de 20 al reabrirlo. Word los reinserta correctamente en su
/// siguiente maquetado, y nuestro visor cae en su heurística para documentos
/// sin marcadores — el mismo comportamiento que ya tienen hoy.
void _stripLastRenderedPageBreaks(XmlDocument document) {
  // `toList()` primero: `descendants` es perezoso y no se puede mutar el
  // árbol mientras se recorre.
  final markers = document.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == 'lastRenderedPageBreak')
      .toList();
  // Se quita solo el elemento. Es `CT_Empty` en OOXML: no aporta ningún
  // carácter al texto plano, así que el `w:r` que lo contenga queda vacío
  // pero válido y sigue aportando cero caracteres — ni un solo carácter
  // visible cambia.
  for (final marker in markers) {
    marker.remove();
  }
}

void _walkTable(
  XmlElement table, {
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
          final key = _pathKey(steps);
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

  final groups = _editableGroups(nodes);
  if (groups.isEmpty) {
    // ponytail: chunk sin ningún w:t editable (p.ej. solo tabs) — no hay
    // dónde escribir; se deja el XML original intacto en vez de adivinar.
    return;
  }

  for (final group in groups) {
    final local = <DocxTextReplacement>[];
    for (final replacement in replacements) {
      if (replacement.startOffset < group.start ||
          replacement.startOffset >= group.end) {
        continue;
      }
      // Un reemplazo no debería cruzar un gap de tab/salto de línea (los
      // campos se extraen de texto visible contiguo), pero si ocurre se
      // recorta al grupo donde empieza y se descarta la cola tras el gap,
      // en vez de construir un empalme entre grupos.
      final end = replacement.endOffset.clamp(group.start, group.end);
      local.add(
        DocxTextReplacement(
          steps: replacement.steps,
          startOffset: replacement.startOffset - group.start,
          endOffset: end - group.start,
          text: replacement.text,
        ),
      );
    }
    if (local.isNotEmpty) {
      _applyToEditableGroup(group.nodes, local);
    }
  }
}

/// Agrupa [nodes] en tramos contiguos de nodos editables (`w:t`), separados
/// por nodos "gap" (`w:tab`/`w:br`). Cada grupo conserva su rango
/// `[start, end)` en offsets del texto plano completo del chunk, para poder
/// traducir un [DocxTextReplacement] a offsets locales del grupo.
List<_EditableGroup> _editableGroups(List<_TextNodeRef> nodes) {
  final groups = <_EditableGroup>[];
  var offset = 0;
  var current = <_TextNodeRef>[];
  var start = 0;
  for (final node in nodes) {
    if (node.isEditable) {
      if (current.isEmpty) {
        start = offset;
      }
      current.add(node);
    } else if (current.isNotEmpty) {
      groups.add((nodes: current, start: start, end: offset));
      current = <_TextNodeRef>[];
    }
    offset += node.text.length;
  }
  if (current.isNotEmpty) {
    groups.add((nodes: current, start: start, end: offset));
  }
  return groups;
}

void _applyToEditableGroup(
  List<_TextNodeRef> nodes,
  List<DocxTextReplacement> replacements,
) {
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

String _pathKey(List<ExportPathStep> steps) {
  final buffer = StringBuffer();
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
  // Espejo de `_collectRawParagraphChunks`: dentro de una tabla los saltos de
  // página se ignoran porque el bloque de tabla es atómico. Si un lado
  // troceara el párrafo de la celda y el otro no, los índices de bloque de
  // celda se desalinearían.
  final ignorePageBreaks = _isInsideTable(paragraph);

  final runs = paragraph.descendants.whereType<XmlElement>().where(
    (element) =>
        element.name.local == 'r' &&
        !_isOutsideParagraphFlow(element, paragraph),
  );

  for (final run in runs) {
    if (_hasDeletedChangeAncestor(run)) {
      continue;
    }
    if (_isHiddenRun(run)) {
      continue;
    }

    for (final element in _runContentElements(run)) {
      final localName = element.name.local;
      if (localName == 't') {
        current.add(_TextNodeRef(element: element, text: element.innerText));
        sawVisible = true;
        endedWithPageBreak = false;
        continue;
      }
      if (localName == 'tab') {
        // Espejo de ingesta: un tab aporta '\t' al texto plano del párrafo.
        // No es un w:t editable, así que entra como nodo "gap" — cuenta para
        // los offsets pero nunca es objetivo de escritura/limpieza.
        current.add(
          _TextNodeRef(element: element, text: '\t', isEditable: false),
        );
        sawVisible = true;
        endedWithPageBreak = false;
        continue;
      }
      if (localName == 'br') {
        if (_isPageBreak(element)) {
          if (!ignorePageBreaks) {
            chunks.add(
              _ParagraphChunkNodes(nodes: current, endsWithPageBreak: true),
            );
            current = <_TextNodeRef>[];
            sawVisible = true;
            endedWithPageBreak = true;
          }
        } else {
          // Espejo de ingesta: un salto de línea manual aporta '\n' como
          // nodo "gap", igual que w:tab arriba.
          current.add(
            _TextNodeRef(element: element, text: '\n', isEditable: false),
          );
          sawVisible = true;
          endedWithPageBreak = false;
        }
        continue;
      }
      if (localName == 'lastRenderedPageBreak' && !ignorePageBreaks) {
        // `lastRenderedPageBreak` SÍ trocea el chunk: espejo de
        // `_collectRawParagraphChunks` en docx_document_repository.dart, que
        // ahora lo honra porque en una plantilla escrita en Word es el único
        // registro de dónde su motor de maquetado cortó cada página. La
        // dirección del espejo no importa mientras los dos lados coincidan:
        // si uno troceara y el otro no, `pageIndex`/`blockIndex` se
        // desalinearían y cada reemplazo caería en el párrafo equivocado.
        // Los marcadores se eliminan del XML exportado (ver
        // `_stripLastRenderedPageBreaks`), después de este recorrido.
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

bool _hasDeletedChangeAncestor(XmlElement run) {
  for (final ancestor in run.ancestors.whereType<XmlElement>()) {
    if (ancestor.name.local == 'del') return true;
  }
  return false;
}

/// Espejo de `_runContentElements` en `docx_document_repository.dart`: el
/// texto de un dibujo o de un cuadro de texto no entra en el flujo del
/// párrafo. Si los dos lados dejaran de coincidir, los offsets del mapeo
/// apuntarían a un texto distinto del que se reemplaza aquí.
Iterable<XmlElement> _runContentElements(XmlElement run) sync* {
  for (final child in run.childElements) {
    final localName = child.name.local;
    if (localName == 'Fallback') {
      continue;
    }
    yield child;
    if (localName == 'drawing' || localName == 'pict' || localName == 'rPr') {
      continue;
    }
    yield* _runContentElements(child);
  }
}

/// Espejo de `_isOutsideParagraphFlow` en `docx_document_repository.dart`.
bool _isOutsideParagraphFlow(XmlElement element, XmlElement paragraph) {
  for (final ancestor in element.ancestors.whereType<XmlElement>()) {
    if (identical(ancestor, paragraph)) {
      return false;
    }
    final localName = ancestor.name.local;
    if (localName == 'Fallback' ||
        localName == 'drawing' ||
        localName == 'pict') {
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

/// Espejo de `_isInsideTable` en `docx_document_repository.dart`: dentro de
/// una celda (`w:tc`, a cualquier profundidad) los saltos de página no
/// trocean el párrafo, porque el bloque de tabla es indivisible.
bool _isInsideTable(XmlElement element) {
  for (final ancestor in element.ancestors.whereType<XmlElement>()) {
    if (ancestor.name.local == 'tc') {
      return true;
    }
  }
  return false;
}

final class _TextNodeRef {
  const _TextNodeRef({
    required this.element,
    required this.text,
    this.isEditable = true,
  });

  final XmlElement element;
  final String text;

  /// `false` for `<w:tab/>`/`<w:br/>` gap nodes: they count toward the
  /// chunk's plain-text offsets (matching ingestion's character accounting)
  /// but are `CT_Empty` in OOXML, so they can never be a write/clear target.
  final bool isEditable;
}

/// A contiguous run of editable [_TextNodeRef]s inside one paragraph chunk,
/// with its `[start, end)` range in the chunk's full plain-text offsets.
typedef _EditableGroup = ({List<_TextNodeRef> nodes, int start, int end});

final class _ParagraphChunkNodes {
  const _ParagraphChunkNodes({
    required this.nodes,
    required this.endsWithPageBreak,
  });

  final List<_TextNodeRef> nodes;
  final bool endsWithPageBreak;
}
