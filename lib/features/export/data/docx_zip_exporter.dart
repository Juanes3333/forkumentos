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

/// One resolved multi-paragraph replacement: expands/contracts the
/// paragraph(s) starting at [rootBlockIndex] to exactly `lines.length`
/// output paragraphs. Covers two source ranges:
/// - [isNumberedList] `true` ("campo de lista"): the range is auto-detected
///   by scanning forward for paragraphs sharing the root's `<w:numId>`.
/// - [isNumberedList] `false` (multi-paragraph prose): the range is exactly
///   [paragraphSpan] consecutive paragraphs starting at [rootBlockIndex],
///   `<w:numId>` is never consulted.
final class DocxListReplacement {
  const DocxListReplacement({
    required this.rootBlockIndex,
    required this.lines,
    required this.isNumberedList,
    this.paragraphSpan,
  });

  /// blockIndex (root-level, same numbering as [DocxTextReplacement.steps]'
  /// `ExportRootBlockStep`) of the first `<w:p>` of the range.
  final int rootBlockIndex;

  /// Cell value split by `\n`; one output paragraph per line.
  final List<String> lines;

  /// `true` to auto-detect the source range by `<w:numId>` (numbered list).
  /// `false` to use exactly [paragraphSpan] consecutive paragraphs.
  final bool isNumberedList;

  /// Number of consecutive source paragraphs to replace when
  /// [isNumberedList] is `false`. Unused otherwise.
  final int? paragraphSpan;
}

/// One resolved cross-paragraph text replacement: the source range starts at
/// [startOffset] in the root-level `<w:p>` at [startBlockIndex] and ends at
/// [endOffset] in the root-level `<w:p>` at [endBlockIndex] (mirrors
/// `FieldAssignment.path`/`startOffset`/`endPath`/`endOffset`).
///
/// [text] is split on `\n`; the first line replaces the start paragraph's
/// tail, the last line replaces the end paragraph's head, and any lines in
/// between become new cloned paragraphs inserted where the original
/// in-between `<w:p>`s were removed. A single-line [text] merges both
/// paragraphs into one and drops the end paragraph.
///
/// Root-level only, like [DocxListReplacement]: a range starting/ending
/// inside a table cell is not supported.
final class DocxRangeReplacement {
  const DocxRangeReplacement({
    required this.startBlockIndex,
    required this.startOffset,
    required this.endBlockIndex,
    required this.endOffset,
    required this.text,
  });

  final int startBlockIndex;
  final int startOffset;
  final int endBlockIndex;
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
    List<DocxListReplacement> listReplacements = const [],
    List<DocxRangeReplacement> rangeReplacements = const [],
  }) {
    final output = Archive();

    for (final entry in prepared.entries) {
      if (entry.name.toLowerCase() == 'word/document.xml') {
        final xml = utf8.decode(entry.bytes, allowMalformed: true);
        final updated = _applyToDocumentXml(
          xml,
          replacements,
          listReplacements,
          rangeReplacements,
        );
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
    List<DocxListReplacement> listReplacements = const [],
    List<DocxRangeReplacement> rangeReplacements = const [],
  }) {
    return applyPrepared(
      prepared: prepare(templateBytes),
      replacements: replacements,
      listReplacements: listReplacements,
      rangeReplacements: rangeReplacements,
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
  List<DocxListReplacement> listReplacements,
  List<DocxRangeReplacement> rangeReplacements,
) {
  if (replacements.isEmpty &&
      listReplacements.isEmpty &&
      rangeReplacements.isEmpty) {
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
  final byRootBlockIndex = <int, DocxListReplacement>{
    for (final listReplacement in listReplacements)
      listReplacement.rootBlockIndex: listReplacement,
  };
  final byStartBlockIndex = <int, DocxRangeReplacement>{
    for (final rangeReplacement in rangeReplacements)
      rangeReplacement.startBlockIndex: rangeReplacement,
  };

  // Absoluto y monotónico, en orden de documento: espejo exacto de
  // `enumerateParagraphTexts` (un incremento por segmento de
  // `_parseContainerBlocks`, incluidos los chunks en los que un párrafo se
  // divide por salto de página). Nada lo reinicia porque nada aguas abajo
  // necesita saber en qué página cae un bloque.
  var blockIndex = 0;

  // Snapshot de los `<w:p>`/`<w:tbl>` de nivel raíz ANTES de mutar nada: las
  // listas se recopilan aquí (por referencia de elemento) pero solo se
  // insertan/eliminan después de terminar este recorrido completo, así que
  // el conteo de `blockIndex` que ven los reemplazos normales nunca se ve
  // afectado por una mutación de lista en un bloque anterior.
  final children = body.childElements.toList();
  final pendingLists = <_PendingListInsertion>[];
  // Head blockIndex (primer chunk de cada `<w:p>`, o el único valor de cada
  // `<w:tbl>`) -> elemento raíz. Espejo del `rootBlockIndex` que ya usan las
  // listas: permite resolver P1/P2 de un rango cruzado después de terminar
  // este recorrido, sin repetir la cuenta de blockIndex.
  final elementByBlockIndex = <int, XmlElement>{};

  for (var i = 0; i < children.length; i++) {
    final child = children[i];
    final localName = child.name.local;
    if (localName == 'p') {
      final paragraphBlockIndex = blockIndex;
      elementByBlockIndex[paragraphBlockIndex] = child;
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
      final listReplacement = byRootBlockIndex[paragraphBlockIndex];
      if (listReplacement != null) {
        pendingLists.add(
          _collectListGroup(children, i, paragraphBlockIndex, listReplacement),
        );
      }
      continue;
    }

    if (localName == 'tbl') {
      elementByBlockIndex[blockIndex] = child;
      _walkTable(child, rootBlockIndex: blockIndex, byPath: byPath);
      blockIndex++;
    }
  }

  // Orden inverso de blockIndex: las mutaciones de una lista posterior nunca
  // desplazan la posición todavía-no-procesada de una lista anterior.
  pendingLists.sort((a, b) => b.blockIndex.compareTo(a.blockIndex));
  for (final pending in pendingLists) {
    _applyListInsertion(body, pending);
  }

  final pendingRanges = _resolvePendingRanges(
    children,
    byStartBlockIndex,
    elementByBlockIndex,
  )..sort((a, b) => b.startBlockIndex.compareTo(a.startBlockIndex));
  for (final pending in pendingRanges) {
    _applyRangeReplacement(body, pending);
  }

  _stripLastRenderedPageBreaks(document);
  return document.toXmlString();
}

/// Recopila el rango de `<w:p>` de origen empezando en
/// `children[startIndex]` (rootBlockIndex ya verificado por el llamador).
///
/// - Lista numerada ([DocxListReplacement.isNumberedList] `true`): el rango
///   son el párrafo raíz y todos los `<w:p>` siguientes que comparten su
///   mismo `<w:numId>`. Si el párrafo mapeado no tiene `<w:numPr>`, la lista
///   degenera a ese único párrafo (no hay como saber dónde termina).
/// - Prosa multi-párrafo (`isNumberedList` `false`): el rango son
///   exactamente [DocxListReplacement.paragraphSpan] párrafos consecutivos;
///   `<w:numId>` no se consulta. Un `paragraphSpan` nulo o <=1 degenera al
///   único párrafo raíz.
_PendingListInsertion _collectListGroup(
  List<XmlElement> children,
  int startIndex,
  int blockIndex,
  DocxListReplacement replacement,
) {
  final head = children[startIndex];
  final group = <XmlElement>[head];

  if (replacement.isNumberedList) {
    final numId = _numIdOf(head);
    if (numId != null) {
      var j = startIndex + 1;
      while (j < children.length) {
        final next = children[j];
        if (next.name.local != 'p' || _numIdOf(next) != numId) {
          break;
        }
        group.add(next);
        j++;
      }
    }
  } else {
    final span = replacement.paragraphSpan ?? 1;
    var j = startIndex + 1;
    while (group.length < span && j < children.length) {
      final next = children[j];
      if (next.name.local != 'p') {
        break;
      }
      group.add(next);
      j++;
    }
  }

  return _PendingListInsertion(
    template: head.copy(),
    toRemove: group,
    lines: replacement.lines,
    blockIndex: blockIndex,
  );
}

/// Elimina [_PendingListInsertion.toRemove] de [body] y en su lugar inserta
/// un clon del párrafo plantilla por cada línea (mismo `<w:numPr>`, así que
/// Word renumera la lista automáticamente).
void _applyListInsertion(XmlElement body, _PendingListInsertion pending) {
  final insertAt = body.children.indexOf(pending.toRemove.first);
  if (insertAt < 0) {
    // ponytail: no debería ocurrir (el elemento viene del mismo snapshot de
    // body.children), pero si pasa, no hay dónde insertar — se deja intacto
    // en vez de lanzar y perder el resto de la fila.
    return;
  }
  for (final element in pending.toRemove) {
    body.children.remove(element);
  }
  var index = insertAt;
  for (final line in pending.lines) {
    body.children.insert(index, _cloneListParagraph(pending.template, line));
    index++;
  }
}

/// Resuelve cada [DocxRangeReplacement] a sus elementos `<w:p>` P1/P2 y a los
/// elementos raíz que quedan estrictamente entre ambos (a eliminar). Un
/// rango cuyo `startBlockIndex`/`endBlockIndex` no resuelva a un `<w:p>`
/// válido en orden creciente se descarta: no hay dónde aplicarlo.
List<_PendingRangeReplacement> _resolvePendingRanges(
  List<XmlElement> children,
  Map<int, DocxRangeReplacement> byStartBlockIndex,
  Map<int, XmlElement> elementByBlockIndex,
) {
  final pending = <_PendingRangeReplacement>[];
  for (final range in byStartBlockIndex.values) {
    final startElement = elementByBlockIndex[range.startBlockIndex];
    final endElement = elementByBlockIndex[range.endBlockIndex];
    if (startElement == null ||
        endElement == null ||
        startElement.name.local != 'p' ||
        endElement.name.local != 'p') {
      continue;
    }
    final startIndex = children.indexOf(startElement);
    final endIndex = children.indexOf(endElement);
    if (startIndex < 0 || endIndex < startIndex) {
      continue;
    }
    pending.add(
      _PendingRangeReplacement(
        startElement: startElement,
        endElement: endElement,
        between: children.sublist(startIndex + 1, endIndex),
        text: range.text,
        startOffset: range.startOffset,
        endOffset: range.endOffset,
        startBlockIndex: range.startBlockIndex,
      ),
    );
  }
  return pending;
}

/// Aplica un reemplazo cruzado entre párrafos: P1 conserva su prefijo, P2 su
/// sufijo, los `<w:p>` intermedios se eliminan, y el texto partido por `\n`
/// se reparte entre P1, clones intermedios y P2. Ver [DocxRangeReplacement].
void _applyRangeReplacement(XmlElement body, _PendingRangeReplacement pending) {
  for (final element in pending.between) {
    body.children.remove(element);
  }

  final startNodes = _splitParagraphChunks(
    pending.startElement,
  ).expand((chunk) => chunk.nodes).toList();
  final startPlainLen = _plainTextLength(startNodes);
  final lines = pending.text.split('\n');

  if (identical(pending.startElement, pending.endElement)) {
    // ponytail: degenerado (mismo párrafo) — no debería ocurrir para un
    // rango cruzado real, pero se resuelve como un reemplazo normal en vez
    // de fallar.
    _spliceEditableRange(
      startNodes,
      start: pending.startOffset,
      end: pending.endOffset.clamp(0, startPlainLen),
      text: pending.text,
    );
    return;
  }

  final endNodes = _splitParagraphChunks(
    pending.endElement,
  ).expand((chunk) => chunk.nodes).toList();

  if (lines.length == 1) {
    final endPlain = endNodes.map((node) => node.text).join();
    final suffix = endPlain.substring(
      pending.endOffset.clamp(0, endPlain.length),
    );
    _spliceEditableRange(
      startNodes,
      start: pending.startOffset,
      end: startPlainLen,
      text: lines.first + suffix,
    );
    body.children.remove(pending.endElement);
    return;
  }

  _spliceEditableRange(
    startNodes,
    start: pending.startOffset,
    end: startPlainLen,
    text: lines.first,
  );
  _spliceEditableRange(
    endNodes,
    start: 0,
    end: pending.endOffset,
    text: lines.last,
  );

  final insertAt = body.children.indexOf(pending.endElement);
  if (insertAt >= 0) {
    var index = insertAt;
    for (final middle in lines.sublist(1, lines.length - 1)) {
      body.children.insert(
        index,
        _cloneListParagraph(pending.startElement, middle),
      );
      index++;
    }
  }
}

int _plainTextLength(List<_TextNodeRef> nodes) {
  var length = 0;
  for (final node in nodes) {
    length += node.text.length;
  }
  return length;
}

/// Reemplaza el texto de [nodes] (chunk de un párrafo, incluidos nodos
/// "gap" como `w:tab`/`w:br`) entre [start] y [end] por [text].
///
/// A diferencia de [_applyToTextNodes]/`_applyToEditableGroup` (pensados
/// para un rango que siempre reemplaza texto existente dentro de un mismo
/// grupo), esto admite `start == end` en el borde de un grupo editable: el
/// caso normal que produce un rango cruzado entre párrafos al insertar justo
/// al final o al principio de un párrafo.
///
/// ponytail: si [start]/[end] no caben en un único grupo editable (p.ej. el
/// rango cruza un `w:tab` dentro del propio párrafo de inicio/fin), se
/// aplica sobre el primer grupo como mejor esfuerzo en vez de fragmentar el
/// texto entre grupos — sube a un splice multi-grupo si un template real lo
/// necesita.
void _spliceEditableRange(
  List<_TextNodeRef> nodes, {
  required int start,
  required int end,
  required String text,
}) {
  final groups = _editableGroups(nodes);
  if (groups.isEmpty) {
    return;
  }
  final target = groups.firstWhere(
    (group) => start >= group.start && end <= group.end,
    orElse: () => groups.first,
  );
  final localStart = (start - target.start).clamp(0, target.end - target.start);
  final localEnd = (end - target.start)
      .clamp(0, target.end - target.start)
      .clamp(localStart, target.end - target.start);
  _rewriteEditableGroup(target.nodes, <_GroupTextOp>[
    (start: localStart, end: localEnd, text: text),
  ]);
}

/// Clona el `<w:p>` plantilla y pone [text] en el primer `<w:t>` de su
/// primer `<w:r>`, eliminando los demás runs — el clon más simple que
/// preserva el formato del primer run y el `<w:numPr>` heredado.
XmlElement _cloneListParagraph(XmlElement template, String text) {
  final clone = template.copy();
  final runs = clone.childElements
      .where((element) => element.name.local == 'r')
      .toList();
  if (runs.isEmpty) {
    return clone;
  }
  for (final extra in runs.skip(1)) {
    extra.remove();
  }
  final textNodes = runs.first.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == 't')
      .toList();
  if (textNodes.isEmpty) {
    return clone;
  }
  textNodes.first.innerText = text;
  for (final extra in textNodes.skip(1)) {
    extra.innerText = '';
  }
  return clone;
}

/// Lee `<w:pPr><w:numPr><w:numId w:val="X"/></w:numPr></w:pPr>` de [paragraph].
int? _numIdOf(XmlElement paragraph) {
  for (final pPr in paragraph.childElements.where(
    (element) => element.name.local == 'pPr',
  )) {
    for (final numPr in pPr.childElements.where(
      (element) => element.name.local == 'numPr',
    )) {
      for (final numId in numPr.childElements.where(
        (element) => element.name.local == 'numId',
      )) {
        for (final attribute in numId.attributes) {
          if (attribute.name.local == 'val') {
            return int.tryParse(attribute.value);
          }
        }
      }
    }
  }
  return null;
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

  // Un reemplazo puede cruzar múltiples gaps de tab/salto de línea
  // cuando el texto mapeado del documento usa tabuladores entre
  // palabras (común en celdas de tabla con alineación manual).
  // En ese caso, el texto de reemplazo va al primer grupo y los
  // grupos posteriores cubiertos se vacían; los gaps intermedios
  // se eliminan del XML en un segundo pass.
  for (final group in groups) {
    final local = <DocxTextReplacement>[];
    for (final replacement in replacements) {
      // ¿El rango del reemplazo tiene alguna intersección con este grupo?
      if (replacement.startOffset >= group.end ||
          replacement.endOffset <= group.start) {
        continue;
      }

      if (replacement.startOffset >= group.start) {
        // Caso normal: el reemplazo EMPIEZA en este grupo.
        // Clampar el end al fin del grupo (la cola se manejará en grupos
        // posteriores como "borrado por continuación").
        final end = replacement.endOffset.clamp(group.start, group.end);
        local.add(
          DocxTextReplacement(
            steps: replacement.steps,
            startOffset: replacement.startOffset - group.start,
            endOffset: end - group.start,
            text: replacement.text,
          ),
        );
      } else {
        // Caso nuevo: el reemplazo EMPEZÓ en un grupo anterior y su texto
        // ya fue escrito allá. Este grupo está total o parcialmente cubierto
        // por la cola del reemplazo → hay que borrar la porción cubierta.
        final localEnd = replacement.endOffset.clamp(group.start, group.end);
        local.add(
          DocxTextReplacement(
            steps: replacement.steps,
            startOffset: 0,
            endOffset: localEnd - group.start,
            text: '',
          ),
        );
      }
    }
    if (local.isNotEmpty) {
      _applyToEditableGroup(group.nodes, local);
    }
  }

  // Segundo pass: eliminar gap nodes cubiertos por reemplazos que cruzan
  // grupos.
  var gapOffset = 0;
  for (final node in nodes) {
    if (!node.isEditable) {
      // Es un gap node (tab o br). ¿Está dentro del rango de algún reemplazo?
      for (final replacement in replacements) {
        if (gapOffset >= replacement.startOffset &&
            gapOffset < replacement.endOffset) {
          // El gap cae dentro del rango reemplazado → eliminar del XML.
          // Buscar el <w:r> padre y eliminarlo si este gap es su único
          // contenido funcional. Si el <w:r> tiene otros hijos, solo
          // eliminar el gap element.
          final parent = node.element.parentElement;
          if (parent != null && parent.name.local == 'r') {
            final functionalChildren = parent.childElements
                .where((e) => e.name.local != 'rPr')
                .toList();
            if (functionalChildren.length == 1 &&
                functionalChildren.first == node.element) {
              parent.remove();
            } else {
              node.element.remove();
            }
          } else {
            node.element.remove();
          }
          break;
        }
      }
    }
    gapOffset += node.text.length;
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
  _rewriteEditableGroup(nodes, <_GroupTextOp>[
    for (final replacement in replacements)
      (
        start: replacement.startOffset,
        end: replacement.endOffset,
        text: replacement.text,
      ),
  ]);
}

/// One text edit inside a single editable group, in the group's own
/// plain-text offsets. `start == end` is a pure insertion.
typedef _GroupTextOp = ({int start, int end, String text});

/// One stretch of output text plus the original offset whose run supplies its
/// formatting. For replacement text that offset is where the replaced span
/// began, so a mapped field that was bold end-to-end stays bold and a mixed
/// span inherits the run it started in.
final class _GroupSegment {
  const _GroupSegment({
    required this.sourceOffset,
    required this.text,
    required this.isReplacement,
  });

  final int sourceOffset;
  final String text;
  final bool isReplacement;
}

/// Rewrites the text of one contiguous editable group ([nodes] — the `<w:t>`
/// nodes of a single run of runs, no gap nodes) applying [ops], then
/// distributes the result back across the original nodes so every `<w:r>`
/// keeps its own `<w:rPr>` formatting.
///
/// This replaced a version that dumped all merged text into the first `<w:t>`
/// and blanked the rest (Bug 4): a paragraph mixing bold and non-bold runs
/// came out entirely in the first run's style — bold lost or bold added.
void _rewriteEditableGroup(List<_TextNodeRef> nodes, List<_GroupTextOp> ops) {
  if (nodes.isEmpty) {
    return;
  }

  final nodeStarts = <int>[];
  var offset = 0;
  for (final node in nodes) {
    nodeStarts.add(offset);
    offset += node.text.length;
  }
  final totalLength = offset;
  final plain = nodes.map((node) => node.text).join();

  final sorted = [...ops]..sort((a, b) => a.start.compareTo(b.start));

  final segments = <_GroupSegment>[];
  var cursor = 0;
  for (final op in sorted) {
    final start = op.start.clamp(0, totalLength);
    final end = op.end.clamp(start, totalLength);
    if (start < cursor) {
      // Overlaps a previous op — skip, matching the old cursor guard.
      continue;
    }
    if (start > cursor) {
      segments.add(
        _GroupSegment(
          sourceOffset: cursor,
          text: plain.substring(cursor, start),
          isReplacement: false,
        ),
      );
    }
    segments.add(
      _GroupSegment(sourceOffset: start, text: op.text, isReplacement: true),
    );
    cursor = end;
  }
  if (cursor < totalLength) {
    segments.add(
      _GroupSegment(
        sourceOffset: cursor,
        text: plain.substring(cursor),
        isReplacement: false,
      ),
    );
  }

  int nodeIndexFor(int sourceOffset) {
    for (var i = nodes.length - 1; i > 0; i--) {
      if (sourceOffset >= nodeStarts[i]) {
        return i;
      }
    }
    return 0;
  }

  final nodeTexts = List<String>.filled(nodes.length, '');
  for (final segment in segments) {
    if (segment.text.isEmpty) {
      continue;
    }
    if (segment.isReplacement || nodes.length == 1) {
      nodeTexts[nodeIndexFor(segment.sourceOffset)] += segment.text;
      continue;
    }
    // Unchanged text: hand each node back exactly its own slice, so a run
    // sitting between two replaced fields keeps its text and style.
    var originalPos = segment.sourceOffset;
    var textPos = 0;
    while (textPos < segment.text.length) {
      final index = nodeIndexFor(originalPos);
      final nodeEnd = index + 1 < nodes.length
          ? nodeStarts[index + 1]
          : totalLength;
      var take = nodeEnd - originalPos;
      if (take <= 0) {
        // Empty run at this offset (shouldn't happen mid-segment): dump the
        // remainder here rather than spin forever.
        nodeTexts[index] += segment.text.substring(textPos);
        break;
      }
      if (take > segment.text.length - textPos) {
        take = segment.text.length - textPos;
      }
      nodeTexts[index] += segment.text.substring(textPos, textPos + take);
      textPos += take;
      originalPos += take;
    }
  }

  for (var i = 0; i < nodes.length; i++) {
    nodes[i].element.innerText = nodeTexts[i];
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

/// A numbered-list expansion queued during the read-only body walk, applied
/// only after that walk finishes so it never perturbs `blockIndex` for
/// normal-text replacements computed in the same pass.
final class _PendingListInsertion {
  const _PendingListInsertion({
    required this.template,
    required this.toRemove,
    required this.lines,
    required this.blockIndex,
  });

  final XmlElement template;
  final List<XmlElement> toRemove;
  final List<String> lines;
  final int blockIndex;
}

/// A cross-paragraph range replacement queued during the read-only body
/// walk, resolved and applied only after that walk finishes — same reason
/// as [_PendingListInsertion].
final class _PendingRangeReplacement {
  const _PendingRangeReplacement({
    required this.startElement,
    required this.endElement,
    required this.between,
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.startBlockIndex,
  });

  final XmlElement startElement;
  final XmlElement endElement;
  final List<XmlElement> between;
  final String text;
  final int startOffset;
  final int endOffset;
  final int startBlockIndex;
}
