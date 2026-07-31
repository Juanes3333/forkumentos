import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:forkumentos/shared/data/document_repository.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

typedef _SerializedRun = Map<String, Object?>;
typedef _SerializedParagraph = List<_SerializedRun>;
typedef _SerializedBlock = Map<String, Object?>;
typedef _SerializedPage = List<_SerializedBlock>;

const _invalidDocxMessage = 'El archivo no es un documento DOCX válido.';
const _invalidDocumentXmlMessage =
    'El archivo word/document.xml no es un XML válido.';

const _defaultPageWidthPoints = 612.0;
const _defaultPageHeightPoints = 792.0;
const _defaultMarginPoints = 72.0;
const _twipsPerPoint = 20.0;

// ponytail: estimación heurística por caracteres/líneas, NO reflow real.
// Fuente de cuerpo asumida ~11pt con interlineado ~1.15 — el "Normal" por
// defecto de Word/Office modernos (Calibri/Aptos 11), NO el 14pt/1.3 de
// AppTypography.dense (tipografía de chrome de la app: botones, etiquetas de
// UI, sin relación con el cuerpo de un documento real). Calibrado para
// coincidir con el tamaño de "cuerpo de documento simulado" que
// document_viewer_screen.dart usa al renderizar, independiente del tema de
// la app, para que la heurística y lo que se ve en pantalla sean
// consistentes (WYSIWYG). Ancho promedio de carácter como la mitad del
// tamaño de fuente (misma fracción típica para fuentes proporcionales).
// Techo conocido: sin métricas de fuente reales esto puede sobre/sub-estimar
// cuánto contenido cabe por página; es un relleno de huecos para texto sin
// ningún marcador explícito, no un motor tipográfico. Mejora futura: medir
// con las métricas reales de la fuente del documento.
const _estimatedFontSizePoints = 11.0;
const _lineHeightRatio = 1.15;
const _charWidthRatio = 0.5;
const _estimatedLineHeightPoints = _estimatedFontSizePoints * _lineHeightRatio;

final class DocxDocumentRepository implements DocumentRepository {
  const DocxDocumentRepository();

  @override
  Future<Document> load(String filePath) async {
    final normalizedExtension = p.extension(filePath).toLowerCase();
    if (normalizedExtension != '.docx') {
      throw const FormatException('Selecciona un archivo con extensión .docx.');
    }

    final bytes = await File(filePath).readAsBytes();
    final payload = await compute<Map<String, Object?>, Map<String, Object?>>(
      _parseDocxContent,
      <String, Object?>{'bytes': bytes},
    );
    return _documentFromPayload(payload);
  }
}

Map<String, Object?> _parseDocxContent(Map<String, Object?> payload) {
  final bytes = payload['bytes'];
  if (bytes is! Uint8List) {
    throw const FormatException(_invalidDocxMessage);
  }

  final archive = _decodeArchive(bytes);
  final archiveEntries = _indexArchiveEntries(archive);

  _requireEntry(
    archiveEntries,
    requiredPath: '[Content_Types].xml',
    message: 'El DOCX no contiene [Content_Types].xml.',
  );
  _requireEntry(
    archiveEntries,
    requiredPath: 'word/document.xml',
    message: 'El DOCX no contiene word/document.xml.',
  );

  final omissions = <DocumentOmission>{};
  _collectArchiveOmissions(archiveEntries, omissions);

  final stylesTable = _parseStylesTable(archiveEntries);

  final documentXml = _archiveEntryAsString(
    archiveEntries['word/document.xml']!,
  );
  final document = _parseDocumentXml(documentXml);
  final body = _findBody(document);
  final sectionProperties = _findSectionProperties(body);
  final sectionMetrics = _parseSectionMetrics(sectionProperties);
  final pages = _extractPages(body, omissions, sectionMetrics, stylesTable);

  final headerSegments = _resolveSectionReferenceBlocks(
    sectionProperties,
    archiveEntries,
    omissions,
    stylesTable,
    referenceLocalName: 'headerReference',
  );
  final footerSegments = _resolveSectionReferenceBlocks(
    sectionProperties,
    archiveEntries,
    omissions,
    stylesTable,
    referenceLocalName: 'footerReference',
  );
  // ponytail: si ni header ni footer se pudieron resolver pero el ZIP sí
  // contiene esos archivos, se conserva la omisión honesta existente. Si se
  // resolvió al menos uno, se asume que hay suficiente contenido mostrable y
  // no se marca como omitido. Resolución parcial (uno sí, otro no) no genera
  // una omisión separada; techo aceptado por simplicidad.
  if (headerSegments == null &&
      footerSegments == null &&
      _hasHeaderOrFooterEntries(archiveEntries)) {
    omissions.add(DocumentOmission.headerFooter);
  }

  final sortedOmissions = omissions.toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  return <String, Object?>{
    'widthPoints': sectionMetrics.widthPoints,
    'heightPoints': sectionMetrics.heightPoints,
    'margins': <String, Object?>{
      'topPoints': sectionMetrics.margins.topPoints,
      'rightPoints': sectionMetrics.margins.rightPoints,
      'bottomPoints': sectionMetrics.margins.bottomPoints,
      'leftPoints': sectionMetrics.margins.leftPoints,
    },
    'pages': <Object?>[
      for (final page in pages)
        <Object?>[
          for (final block in page) <String, Object?>{...block},
        ],
    ],
    'header': <Object?>[
      for (final segment in headerSegments ?? const <_SerializedBlockSegment>[])
        <String, Object?>{...segment.block},
    ],
    'footer': <Object?>[
      for (final segment in footerSegments ?? const <_SerializedBlockSegment>[])
        <String, Object?>{...segment.block},
    ],
    'omissions': <Object?>[
      for (final omission in sortedOmissions) omission.name,
    ],
  };
}

Document _documentFromPayload(Map<String, Object?> payload) {
  final widthPoints = _asDouble(
    payload['widthPoints'],
    _defaultPageWidthPoints,
  );
  final heightPoints = _asDouble(
    payload['heightPoints'],
    _defaultPageHeightPoints,
  );

  final marginsRaw = payload['margins'];
  final marginsMap = marginsRaw is Map<Object?, Object?>
      ? marginsRaw
      : const <Object?, Object?>{};
  final margins = DocumentMargins(
    topPoints: _asDouble(marginsMap['topPoints'], _defaultMarginPoints),
    rightPoints: _asDouble(marginsMap['rightPoints'], _defaultMarginPoints),
    bottomPoints: _asDouble(marginsMap['bottomPoints'], _defaultMarginPoints),
    leftPoints: _asDouble(marginsMap['leftPoints'], _defaultMarginPoints),
  );

  final pagesRaw = payload['pages'];
  final pagesList = pagesRaw is List<Object?> ? pagesRaw : const <Object?>[];
  final pages = List<DocumentPage>.generate(pagesList.length, (index) {
    final pageRaw = pagesList[index];
    final pageBlocksRaw = pageRaw is List<Object?>
        ? pageRaw
        : const <Object?>[];

    final blocks = <DocumentBlock>[
      for (final blockRaw in pageBlocksRaw) _blockFromPayload(blockRaw),
    ];

    return DocumentPage(
      number: index + 1,
      widthPoints: widthPoints,
      heightPoints: heightPoints,
      margins: margins,
      blocks: blocks,
    );
  });

  final omissionsRaw = payload['omissions'];
  final omissionsList = omissionsRaw is List<Object?>
      ? omissionsRaw
      : const <Object?>[];
  final omissions = <DocumentOmission>{
    for (final omissionRaw in omissionsList)
      if (omissionRaw is String) ...<DocumentOmission>{
        for (final omission in DocumentOmission.values)
          if (omission.name == omissionRaw) omission,
      },
  };

  final headerRaw = payload['header'];
  final headerBlocksRaw = headerRaw is List<Object?>
      ? headerRaw
      : const <Object?>[];
  final header = <DocumentBlock>[
    for (final blockRaw in headerBlocksRaw) _blockFromPayload(blockRaw),
  ];

  final footerRaw = payload['footer'];
  final footerBlocksRaw = footerRaw is List<Object?>
      ? footerRaw
      : const <Object?>[];
  final footer = <DocumentBlock>[
    for (final blockRaw in footerBlocksRaw) _blockFromPayload(blockRaw),
  ];

  return Document(
    pages: pages,
    omissions: omissions,
    header: header,
    footer: footer,
  );
}

DocumentBlock _blockFromPayload(Object? blockRaw) {
  final blockMap = blockRaw is Map<Object?, Object?>
      ? blockRaw
      : const <Object?, Object?>{};
  final kind = blockMap['kind'] as String?;

  if (kind == 'table') {
    return DocumentBlock.table(_tableFromPayload(blockMap['rows']));
  }

  final runsRaw = blockMap['runs'];
  final runsList = runsRaw is List<Object?> ? runsRaw : const <Object?>[];
  return DocumentBlock.paragraph(
    DocumentParagraph(
      runs: <DocumentRun>[
        for (final runRaw in runsList) _runFromPayload(runRaw),
      ],
      spacingBeforePoints: _asDouble(blockMap['spacingBeforePoints'], 0),
      spacingAfterPoints: _asDouble(blockMap['spacingAfterPoints'], 0),
      keepWithNext: blockMap['keepWithNext'] as bool? ?? false,
    ),
  );
}

DocumentTable _tableFromPayload(Object? rowsRaw) {
  final rowsList = rowsRaw is List<Object?> ? rowsRaw : const <Object?>[];

  return DocumentTable(
    rows: <DocumentTableRow>[
      for (final rowRaw in rowsList)
        DocumentTableRow(
          cells: <DocumentTableCell>[
            for (final cellRaw in _rowCellsRaw(rowRaw))
              DocumentTableCell(
                blocks: <DocumentBlock>[
                  for (final blockRaw in _cellBlocksRaw(cellRaw))
                    _blockFromPayload(blockRaw),
                ],
              ),
          ],
        ),
    ],
  );
}

List<Object?> _rowCellsRaw(Object? rowRaw) {
  final rowMap = rowRaw is Map<Object?, Object?>
      ? rowRaw
      : const <Object?, Object?>{};
  final cellsRaw = rowMap['cells'];
  return cellsRaw is List<Object?> ? cellsRaw : const <Object?>[];
}

List<Object?> _cellBlocksRaw(Object? cellRaw) {
  final cellMap = cellRaw is Map<Object?, Object?>
      ? cellRaw
      : const <Object?, Object?>{};
  final blocksRaw = cellMap['blocks'];
  return blocksRaw is List<Object?> ? blocksRaw : const <Object?>[];
}

DocumentRun _runFromPayload(Object? runRaw) {
  final runMap = runRaw is Map<Object?, Object?>
      ? runRaw
      : const <Object?, Object?>{};
  return DocumentRun(
    text: runMap['text'] as String? ?? '',
    isBold: runMap['isBold'] as bool? ?? false,
    isItalic: runMap['isItalic'] as bool? ?? false,
    isUnderlined: runMap['isUnderlined'] as bool? ?? false,
    colorHex: runMap['colorHex'] as String?,
    fontSizePoints: _asNullableDouble(runMap['fontSizePoints']),
  );
}

double _asDouble(Object? value, double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

double? _asNullableDouble(Object? value) =>
    value is num ? value.toDouble() : null;

Archive _decodeArchive(Uint8List bytes) {
  if (!_looksLikeZip(bytes)) {
    throw const FormatException(_invalidDocxMessage);
  }

  try {
    return ZipDecoder().decodeBytes(bytes, verify: true);
  } catch (_) {
    throw const FormatException(_invalidDocxMessage);
  }
}

bool _looksLikeZip(Uint8List bytes) {
  if (bytes.length < 4) {
    return false;
  }

  return bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
      (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08);
}

Map<String, ArchiveFile> _indexArchiveEntries(Archive archive) {
  return <String, ArchiveFile>{
    for (final file in archive.files) file.name.toLowerCase(): file,
  };
}

void _requireEntry(
  Map<String, ArchiveFile> entries, {
  required String requiredPath,
  required String message,
}) {
  if (!entries.containsKey(requiredPath.toLowerCase())) {
    throw FormatException(message);
  }
}

String _archiveEntryAsString(ArchiveFile file) {
  final content = file.content;
  if (content is List<int>) {
    return utf8.decode(content, allowMalformed: true);
  }
  if (content is String) {
    return content;
  }
  throw const FormatException(_invalidDocxMessage);
}

void _collectArchiveOmissions(
  Map<String, ArchiveFile> entries,
  Set<DocumentOmission> omissions,
) {
  final hasFootnotes =
      entries.containsKey('word/footnotes.xml') ||
      entries.containsKey('word/endnotes.xml');
  if (hasFootnotes) {
    omissions.add(DocumentOmission.footnote);
  }
}

bool _hasHeaderOrFooterEntries(Map<String, ArchiveFile> entries) {
  return entries.keys.any((path) {
    final isHeader = path.startsWith('word/header') && path.endsWith('.xml');
    final isFooter = path.startsWith('word/footer') && path.endsWith('.xml');
    return isHeader || isFooter;
  });
}

XmlDocument _parseDocumentXml(String xmlContent) {
  try {
    return XmlDocument.parse(xmlContent);
  } catch (_) {
    throw const FormatException(_invalidDocumentXmlMessage);
  }
}

XmlElement _findBody(XmlDocument document) {
  for (final element in document.descendants.whereType<XmlElement>()) {
    if (element.name.local == 'body') {
      return element;
    }
  }
  throw const FormatException(_invalidDocumentXmlMessage);
}

// ponytail: se toma el PRIMER sectPr del documento (documentos de una sola
// sección). Documentos multi-sección con encabezados/pies distintos por
// sección quedan fuera de alcance, igual que ya lo estaba el tamaño de
// página; el techo es el mismo de siempre, ahora compartido por ambos usos.
XmlElement? _findSectionProperties(XmlElement body) {
  for (final element in body.descendants.whereType<XmlElement>()) {
    if (element.name.local == 'sectPr') {
      return element;
    }
  }
  return null;
}

_SectionMetrics _parseSectionMetrics(XmlElement? sectionProperties) {
  XmlElement? pageSize;
  XmlElement? pageMargins;
  if (sectionProperties != null) {
    for (final element
        in sectionProperties.descendants.whereType<XmlElement>()) {
      if (pageSize == null && element.name.local == 'pgSz') {
        pageSize = element;
      } else if (pageMargins == null && element.name.local == 'pgMar') {
        pageMargins = element;
      }

      if (pageSize != null && pageMargins != null) {
        break;
      }
    }
  }

  return _SectionMetrics(
    widthPoints: _pointsFromTwipsAttribute(
      pageSize,
      attributeLocalName: 'w',
      fallback: _defaultPageWidthPoints,
    ),
    heightPoints: _pointsFromTwipsAttribute(
      pageSize,
      attributeLocalName: 'h',
      fallback: _defaultPageHeightPoints,
    ),
    margins: DocumentMargins(
      topPoints: _pointsFromTwipsAttribute(
        pageMargins,
        attributeLocalName: 'top',
        fallback: _defaultMarginPoints,
      ),
      rightPoints: _pointsFromTwipsAttribute(
        pageMargins,
        attributeLocalName: 'right',
        fallback: _defaultMarginPoints,
      ),
      bottomPoints: _pointsFromTwipsAttribute(
        pageMargins,
        attributeLocalName: 'bottom',
        fallback: _defaultMarginPoints,
      ),
      leftPoints: _pointsFromTwipsAttribute(
        pageMargins,
        attributeLocalName: 'left',
        fallback: _defaultMarginPoints,
      ),
    ),
  );
}

// ponytail: resuelve header/footer únicamente vía `w:type="default"` (o el
// primer `headerReference`/`footerReference` si no hay uno "default").
// first/even quedan fuera de alcance — mismo criterio de simplicidad que ya
// aplica al resto del parser. Retorna null si cualquier paso de la cadena
// (referencia -> relación -> archivo -> XML) no se puede resolver, para que
// el llamador decida si eso amerita la omisión `headerFooter`.
List<_SerializedBlockSegment>? _resolveSectionReferenceBlocks(
  XmlElement? sectionProperties,
  Map<String, ArchiveFile> archiveEntries,
  Set<DocumentOmission> omissions,
  _StylesTable stylesTable, {
  required String referenceLocalName,
}) {
  if (sectionProperties == null) {
    return null;
  }

  final relationshipId = _findReferenceRelationshipId(
    sectionProperties,
    referenceLocalName,
  );
  if (relationshipId == null) {
    return null;
  }

  final target = _resolveRelationshipTarget(relationshipId, archiveEntries);
  if (target == null) {
    return null;
  }

  final normalizedTarget =
      (target.startsWith('word/') ? target : 'word/$target').toLowerCase();
  final entry = archiveEntries[normalizedTarget];
  if (entry == null) {
    return null;
  }

  XmlDocument parsed;
  try {
    parsed = XmlDocument.parse(_archiveEntryAsString(entry));
  } catch (_) {
    return null;
  }

  return _parseContainerBlocks(parsed.rootElement, omissions, stylesTable);
}

String? _findReferenceRelationshipId(
  XmlElement sectionProperties,
  String referenceLocalName,
) {
  XmlElement? defaultReference;
  XmlElement? firstReference;
  for (final child in sectionProperties.childElements) {
    if (child.name.local != referenceLocalName) {
      continue;
    }
    firstReference ??= child;
    if (_attributeValue(child, 'type') == 'default') {
      defaultReference = child;
      break;
    }
  }

  final reference = defaultReference ?? firstReference;
  if (reference == null) {
    return null;
  }
  return _attributeValue(reference, 'id');
}

String? _resolveRelationshipTarget(
  String relationshipId,
  Map<String, ArchiveFile> archiveEntries,
) {
  final relsEntry = archiveEntries['word/_rels/document.xml.rels'];
  if (relsEntry == null) {
    return null;
  }

  XmlDocument relsDocument;
  try {
    relsDocument = XmlDocument.parse(_archiveEntryAsString(relsEntry));
  } catch (_) {
    return null;
  }

  for (final relationship in relsDocument.descendants.whereType<XmlElement>()) {
    if (relationship.name.local != 'Relationship') {
      continue;
    }
    if (_attributeValue(relationship, 'Id') == relationshipId) {
      return _attributeValue(relationship, 'Target');
    }
  }
  return null;
}

double _pointsFromTwipsAttribute(
  XmlElement? element, {
  required String attributeLocalName,
  required double fallback,
}) {
  if (element == null) {
    return fallback;
  }

  final rawValue = _attributeValue(element, attributeLocalName);
  final twips = int.tryParse(rawValue ?? '');
  if (twips == null) {
    return fallback;
  }

  return twips / _twipsPerPoint;
}

String? _attributeValue(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) {
      return attribute.value;
    }
  }
  return null;
}

// ponytail: la paginación se basa primero en marcadores explícitos
// (`w:br type="page"` / `w:lastRenderedPageBreak` / `w:pageBreakBefore` /
// fin de sección intermedia). Cuando ninguna señal explícita cae en un
// tramo del documento, una heurística de caracteres/líneas (ver constantes
// `_estimated*`) rellena el hueco para que texto continuo largo no colapse
// en una sola página kilométrica. No se reproduce el reflow automático de
// Word (que depende de métricas de fuente y layout reales); el techo:
// fidelidad de paginación automática requeriría un motor tipográfico OOXML
// completo, fuera de alcance de este sprint.
List<_SerializedPage> _extractPages(
  XmlElement body,
  Set<DocumentOmission> omissions,
  _SectionMetrics sectionMetrics,
  _StylesTable stylesTable,
) {
  final pages = <_SerializedPage>[];
  var currentPageBlocks = <_SerializedBlock>[];
  var currentPageHeightPoints = 0.0;

  final contentWidthPoints =
      sectionMetrics.widthPoints -
      sectionMetrics.margins.leftPoints -
      sectionMetrics.margins.rightPoints;
  final contentHeightPoints =
      sectionMetrics.heightPoints -
      sectionMetrics.margins.topPoints -
      sectionMetrics.margins.bottomPoints;

  for (final segment in _parseContainerBlocks(
    body,
    omissions,
    stylesTable,
    respectPageBreakBefore: true,
  )) {
    final segmentHeightPoints = _estimatedSegmentHeightPoints(
      segment.block,
      contentWidthPoints,
    );

    // La heurística solo actúa cuando aún no hay una señal explícita que ya
    // haya cortado esta zona: si excede el presupuesto vertical estimado,
    // corta ANTES de este segmento (nunca a mitad de un chunk ya troceado
    // por saltos explícitos).
    if (currentPageBlocks.isNotEmpty &&
        currentPageHeightPoints + segmentHeightPoints > contentHeightPoints) {
      pages.add(currentPageBlocks);
      currentPageBlocks = <_SerializedBlock>[];
      currentPageHeightPoints = 0;
    }

    currentPageBlocks = <_SerializedBlock>[
      ...currentPageBlocks,
      <String, Object?>{...segment.block},
    ];
    currentPageHeightPoints += segmentHeightPoints;

    if (segment.endsWithPageBreak) {
      pages.add(currentPageBlocks);
      currentPageBlocks = <_SerializedBlock>[];
      currentPageHeightPoints = 0;
    }
  }

  if (pages.isEmpty && currentPageBlocks.isEmpty) {
    return <_SerializedPage>[<_SerializedBlock>[]];
  }

  if (currentPageBlocks.isEmpty && pages.isNotEmpty) {
    return pages;
  }

  return <_SerializedPage>[...pages, currentPageBlocks];
}

// ponytail: estimación simple de altura por bloque para la heurística de
// relleno. Párrafos: (líneas estimadas * alto de línea) + spacing
// before/after del párrafo (de la cascada de estilos). Líneas = longitud de
// texto / caracteres-por-línea, ambos derivados del fontSizePoints REAL del
// párrafo (heredado de w:pStyle) cuando existe, o el tamaño de cuerpo
// asumido si no. Tablas: una línea por fila al tamaño de cuerpo asumido (sin
// layout de columnas real) — techo aceptado, ver comentario de
// `_serializeTable` sobre gridSpan/vMerge.
double _estimatedSegmentHeightPoints(
  _SerializedBlock block,
  double contentWidthPoints,
) {
  if (block['kind'] == 'table') {
    final rows = block['rows'];
    final rowCount = rows is List<Object?> && rows.isNotEmpty ? rows.length : 1;
    return rowCount * _estimatedLineHeightPoints;
  }

  final fontSizePoints = _blockFontSizePoints(block);
  final lineHeightPoints = fontSizePoints * _lineHeightRatio;
  final charWidthPoints = fontSizePoints * _charWidthRatio;
  final charsPerLine = math.max(1, contentWidthPoints / charWidthPoints);

  final runsRaw = block['runs'];
  final runs = runsRaw is List<Object?> ? runsRaw : const <Object?>[];
  var textLength = 0;
  for (final runRaw in runs) {
    if (runRaw is Map<String, Object?>) {
      final text = runRaw['text'];
      if (text is String) {
        textLength += text.length;
      }
    }
  }

  final lines = textLength == 0
      ? 1
      : math.max(1, (textLength / charsPerLine).ceil());

  final spacingBeforePoints = _asDouble(block['spacingBeforePoints'], 0);
  final spacingAfterPoints = _asDouble(block['spacingAfterPoints'], 0);

  return lines * lineHeightPoints + spacingBeforePoints + spacingAfterPoints;
}

double _blockFontSizePoints(_SerializedBlock block) {
  final runsRaw = block['runs'];
  final runs = runsRaw is List<Object?> ? runsRaw : const <Object?>[];
  for (final runRaw in runs) {
    if (runRaw is Map<String, Object?>) {
      final fontSize = runRaw['fontSizePoints'];
      if (fontSize is num) {
        return fontSize.toDouble();
      }
    }
  }
  return _estimatedFontSizePoints;
}

List<_SerializedBlockSegment> _parseContainerBlocks(
  XmlElement container,
  Set<DocumentOmission> omissions,
  _StylesTable stylesTable, {
  bool respectPageBreakBefore = false,
}) {
  final segments = <_SerializedBlockSegment>[];

  for (final child in container.childElements) {
    final localName = child.name.local;
    if (localName == 'p') {
      if (respectPageBreakBefore &&
          segments.isNotEmpty &&
          _hasPageBreakBefore(child)) {
        final lastIndex = segments.length - 1;
        segments[lastIndex] = _SerializedBlockSegment(
          block: segments[lastIndex].block,
          endsWithPageBreak: true,
        );
      }

      final chunks = _splitParagraphByPageBreak(child, omissions, stylesTable);
      // Un sectPr embebido en pPr marca fin de sección intermedia, que por
      // defecto en OOXML SIEMPRE implica salto de página. Se aplica al
      // ÚLTIMO chunk generado por este párrafo (el corte ocurre después de
      // su contenido), y solo al nivel del body (no dentro de celdas de
      // tabla ni de header/footer), igual que pageBreakBefore.
      final forcesSectionBreak =
          respectPageBreakBefore && _paragraphSectionBreakEndsPage(child);
      for (var index = 0; index < chunks.length; index++) {
        final chunk = chunks[index];
        final isLastChunk = index == chunks.length - 1;
        segments.add(
          _SerializedBlockSegment(
            block: <String, Object?>{
              'kind': 'paragraph',
              'runs': <Object?>[
                for (final run in chunk.runs) <String, Object?>{...run},
              ],
              'spacingBeforePoints': chunk.spacingBeforePoints,
              'spacingAfterPoints': chunk.spacingAfterPoints,
              'keepWithNext': chunk.keepWithNext,
            },
            endsWithPageBreak:
                chunk.endsWithPageBreak || (isLastChunk && forcesSectionBreak),
          ),
        );
      }
      continue;
    }

    if (localName == 'tbl') {
      segments.add(
        _SerializedBlockSegment(
          block: _serializeTable(child, omissions, stylesTable),
          endsWithPageBreak: false,
        ),
      );
    }
  }

  return segments;
}

_SerializedBlock _serializeTable(
  XmlElement tableElement,
  Set<DocumentOmission> omissions,
  _StylesTable stylesTable,
) {
  final rows = <Object?>[];

  // ponytail: no se interpreta gridSpan/vMerge en esta versión. Cada `w:tc`
  // se renderiza como celda independiente para mantener una implementación
  // mínima y estable. El techo: para fidelidad visual completa de fusiones se
  // necesitaría parseo OOXML adicional de propiedades de tabla y layout.
  for (final rowElement in tableElement.childElements) {
    if (rowElement.name.local != 'tr') {
      continue;
    }

    final cells = <Object?>[];
    for (final cellElement in rowElement.childElements) {
      if (cellElement.name.local != 'tc') {
        continue;
      }

      final nestedSegments = _parseContainerBlocks(
        cellElement,
        omissions,
        stylesTable,
      );
      cells.add(<String, Object?>{
        'blocks': <Object?>[
          for (final segment in nestedSegments)
            <String, Object?>{...segment.block},
        ],
      });
    }

    rows.add(<String, Object?>{'cells': cells});
  }

  return <String, Object?>{'kind': 'table', 'rows': rows};
}

// Resuelve el estilo del párrafo una sola vez y lo aplica en cascada: cada
// run gana con su propia propiedad inline (w:b/w:i/w:u/w:color/w:sz) cuando
// la tiene, si no hereda del párrafo. El spacing before/after y keepWithNext
// del párrafo se atan al PRIMER/ÚLTIMO chunk respectivamente — un párrafo
// solo se fragmenta en varios chunks cuando trae un salto de página
// explícito en medio, caso raro; en el caso común (un solo chunk) ambos
// caen en el mismo chunk, que es lo correcto.
List<_ParagraphChunk> _splitParagraphByPageBreak(
  XmlElement paragraph,
  Set<DocumentOmission> omissions,
  _StylesTable stylesTable,
) {
  final paragraphStyle = stylesTable.resolve(_paragraphStyleId(paragraph));
  final rawChunks = _collectRawParagraphChunks(
    paragraph,
    omissions,
    paragraphStyle,
  );

  return <_ParagraphChunk>[
    for (var index = 0; index < rawChunks.length; index++)
      _ParagraphChunk(
        runs: rawChunks[index].runs,
        endsWithPageBreak: rawChunks[index].endsWithPageBreak,
        spacingBeforePoints: index == 0
            ? paragraphStyle.spacingBeforePoints
            : 0,
        spacingAfterPoints: index == rawChunks.length - 1
            ? paragraphStyle.spacingAfterPoints
            : 0,
        keepWithNext:
            index == rawChunks.length - 1 && paragraphStyle.keepWithNext,
      ),
  ];
}

String? _paragraphStyleId(XmlElement paragraph) {
  final paragraphProperties = _firstChildByLocalName(paragraph, 'pPr');
  if (paragraphProperties == null) {
    return null;
  }
  final pStyle = _firstChildByLocalName(paragraphProperties, 'pStyle');
  if (pStyle == null) {
    return null;
  }
  return _attributeValue(pStyle, 'val');
}

List<_ParagraphChunk> _collectRawParagraphChunks(
  XmlElement paragraph,
  Set<DocumentOmission> omissions,
  _ResolvedParagraphStyle paragraphStyle,
) {
  final chunks = <_ParagraphChunk>[];
  var currentRuns = <_SerializedRun>[];
  var sawVisibleToken = false;
  var endedWithPageBreak = false;

  final runElements = paragraph.descendants.whereType<XmlElement>().where(
    (element) => element.name.local == 'r',
  );

  for (final run in runElements) {
    if (_hasTrackedChangeAncestor(run)) {
      continue;
    }

    final runStyle = _resolveRunStyle(run);
    if (runStyle.isHidden) {
      continue;
    }

    final runText = StringBuffer();

    void flushRunText() {
      final text = runText.toString();
      runText.clear();
      if (text.isEmpty) {
        return;
      }

      currentRuns = <_SerializedRun>[
        ...currentRuns,
        <String, Object?>{
          'text': text,
          'isBold': runStyle.isBold ?? paragraphStyle.isBold,
          'isItalic': runStyle.isItalic ?? paragraphStyle.isItalic,
          'isUnderlined': runStyle.isUnderlined ?? paragraphStyle.isUnderlined,
          'colorHex': runStyle.colorHex ?? paragraphStyle.colorHex,
          'fontSizePoints':
              runStyle.fontSizePoints ?? paragraphStyle.fontSizePoints,
        },
      ];
      sawVisibleToken = true;
      endedWithPageBreak = false;
    }

    for (final element in run.descendants.whereType<XmlElement>()) {
      final localName = element.name.local;

      if (localName == 'drawing' || localName == 'pict') {
        omissions.add(DocumentOmission.image);
      }

      if (localName == 't') {
        runText.write(element.innerText);
        sawVisibleToken = true;
        endedWithPageBreak = false;
        continue;
      }

      if (localName == 'tab') {
        runText.write('\t');
        sawVisibleToken = true;
        endedWithPageBreak = false;
        continue;
      }

      if (localName == 'br') {
        if (_isPageBreak(element)) {
          flushRunText();
          chunks.add(
            _ParagraphChunk(runs: currentRuns, endsWithPageBreak: true),
          );
          currentRuns = <_SerializedRun>[];
          sawVisibleToken = true;
          endedWithPageBreak = true;
        } else {
          runText.write('\n');
          sawVisibleToken = true;
          endedWithPageBreak = false;
        }
        continue;
      }

      if (localName == 'lastRenderedPageBreak') {
        flushRunText();
        chunks.add(_ParagraphChunk(runs: currentRuns, endsWithPageBreak: true));
        currentRuns = <_SerializedRun>[];
        sawVisibleToken = true;
        endedWithPageBreak = true;
      }
    }

    flushRunText();
  }

  if (!sawVisibleToken) {
    return <_ParagraphChunk>[
      const _ParagraphChunk(runs: <_SerializedRun>[], endsWithPageBreak: false),
    ];
  }

  if (!endedWithPageBreak || currentRuns.isNotEmpty) {
    chunks.add(_ParagraphChunk(runs: currentRuns, endsWithPageBreak: false));
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

bool _isPageBreak(XmlElement breakElement) {
  final breakType = _attributeValue(breakElement, 'type');
  return breakType == 'page';
}

bool _hasPageBreakBefore(XmlElement paragraph) {
  XmlElement? paragraphProperties;
  for (final child in paragraph.childElements) {
    if (child.name.local == 'pPr') {
      paragraphProperties = child;
      break;
    }
  }
  if (paragraphProperties == null) {
    return false;
  }

  XmlElement? pageBreakBefore;
  for (final child in paragraphProperties.childElements) {
    if (child.name.local == 'pageBreakBefore') {
      pageBreakBefore = child;
      break;
    }
  }

  return _isEnabledProperty(pageBreakBefore);
}

// ponytail: un sectPr hijo directo de pPr marca el fin de una sección
// intermedia (el sectPr final del documento es hijo directo de body, y ese
// ya se maneja aparte en `_findSectionProperties`). Por spec OOXML el salto
// de sección siempre implica salto de página salvo `w:type` "continuous" o
// "nextColumn"; la ausencia de `w:type` es el default "nextPage", que SÍ
// rompe página.
bool _paragraphSectionBreakEndsPage(XmlElement paragraph) {
  XmlElement? paragraphProperties;
  for (final child in paragraph.childElements) {
    if (child.name.local == 'pPr') {
      paragraphProperties = child;
      break;
    }
  }
  if (paragraphProperties == null) {
    return false;
  }

  XmlElement? sectionProperties;
  for (final child in paragraphProperties.childElements) {
    if (child.name.local == 'sectPr') {
      sectionProperties = child;
      break;
    }
  }
  if (sectionProperties == null) {
    return false;
  }

  XmlElement? sectionType;
  for (final child in sectionProperties.childElements) {
    if (child.name.local == 'type') {
      sectionType = child;
      break;
    }
  }
  if (sectionType == null) {
    return true;
  }

  final typeValue = _attributeValue(sectionType, 'val');
  return typeValue != 'continuous' && typeValue != 'nextColumn';
}

_RunStyle _resolveRunStyle(XmlElement run) {
  final runProperties = _firstChildByLocalName(run, 'rPr');
  if (runProperties == null) {
    return const _RunStyle();
  }

  final parsed = _parseRunProperties(runProperties);
  final hasVanish = _firstChildByLocalName(runProperties, 'vanish') != null;

  return _RunStyle(
    isBold: parsed.isBold,
    isItalic: parsed.isItalic,
    isUnderlined: parsed.isUnderlined,
    colorHex: parsed.colorHex,
    fontSizePoints: parsed.fontSizePoints,
    isHidden: hasVanish,
  );
}

XmlElement? _firstChildByLocalName(XmlElement parent, String localName) {
  for (final child in parent.childElements) {
    if (child.name.local == localName) {
      return child;
    }
  }
  return null;
}

// Parseo compartido de un `<w:rPr>` (de un run inline o de la definición de
// un estilo con nombre en styles.xml): mismas propiedades, mismo shape.
// null en un campo = "no especificado aquí", para que el llamador decida
// cómo hacer cascada (inline gana sobre estilo, estilo gana sobre
// docDefaults).
_RunPropertiesRaw _parseRunProperties(XmlElement? rPr) {
  if (rPr == null) {
    return const _RunPropertiesRaw();
  }

  bool? isBold;
  bool? isItalic;
  bool? isUnderlined;
  String? colorHex;
  double? fontSizePoints;

  for (final property in rPr.childElements) {
    switch (property.name.local) {
      case 'b':
        isBold = _isEnabledProperty(property);
      case 'i':
        isItalic = _isEnabledProperty(property);
      case 'u':
        isUnderlined = _isUnderlineEnabled(property);
      case 'color':
        colorHex = _colorHexFromProperty(property);
      case 'sz':
        fontSizePoints = _fontSizePointsFromProperty(property);
    }
  }

  return _RunPropertiesRaw(
    isBold: isBold,
    isItalic: isItalic,
    isUnderlined: isUnderlined,
    colorHex: colorHex,
    fontSizePoints: fontSizePoints,
  );
}

String? _colorHexFromProperty(XmlElement colorElement) {
  final value = _attributeValue(colorElement, 'val');
  if (value == null || value.isEmpty || value.toLowerCase() == 'auto') {
    return null;
  }
  return value.toUpperCase();
}

double? _fontSizePointsFromProperty(XmlElement szElement) {
  final halfPoints = int.tryParse(_attributeValue(szElement, 'val') ?? '');
  if (halfPoints == null) {
    return null;
  }
  return halfPoints / 2;
}

// Parseo compartido de un `<w:pPr>` para las propiedades que participan en
// la cascada de estilos de párrafo (spacing before/after, keepNext). Igual
// que `_parseRunProperties`: null = "no especificado aquí".
_ParagraphPropertiesRaw _parseParagraphSpacingProperties(XmlElement? pPr) {
  if (pPr == null) {
    return const _ParagraphPropertiesRaw();
  }

  double? spacingBeforePoints;
  double? spacingAfterPoints;
  bool? keepWithNext;

  for (final property in pPr.childElements) {
    if (property.name.local == 'spacing') {
      final beforeTwips = int.tryParse(
        _attributeValue(property, 'before') ?? '',
      );
      final afterTwips = int.tryParse(_attributeValue(property, 'after') ?? '');
      if (beforeTwips != null) {
        spacingBeforePoints = beforeTwips / _twipsPerPoint;
      }
      if (afterTwips != null) {
        spacingAfterPoints = afterTwips / _twipsPerPoint;
      }
    } else if (property.name.local == 'keepNext') {
      keepWithNext = _isEnabledProperty(property);
    }
  }

  return _ParagraphPropertiesRaw(
    spacingBeforePoints: spacingBeforePoints,
    spacingAfterPoints: spacingAfterPoints,
    keepWithNext: keepWithNext,
  );
}

// Indexa `word/styles.xml`: docDefaults resuelto de una vez, y cada estilo
// de párrafo SIN resolver su cadena w:basedOn todavía (eso lo hace
// `_StylesTable.resolve`, con memoización, la primera vez que se pide).
// Ausencia total de styles.xml (o de la entrada) -> tabla vacía, que resuelve
// siempre al docDefaults por defecto (todo false/0/null): mismo
// comportamiento que antes de esta función para documentos sin estilos.
_StylesTable _parseStylesTable(Map<String, ArchiveFile> archiveEntries) {
  final entry = archiveEntries['word/styles.xml'];
  if (entry == null) {
    return _StylesTable(
      docDefaults: const _ResolvedParagraphStyle(),
      rawStyles: const <String, _RawParagraphStyle>{},
    );
  }

  XmlElement root;
  try {
    root = XmlDocument.parse(_archiveEntryAsString(entry)).rootElement;
  } catch (_) {
    return _StylesTable(
      docDefaults: const _ResolvedParagraphStyle(),
      rawStyles: const <String, _RawParagraphStyle>{},
    );
  }

  var docDefaults = const _ResolvedParagraphStyle();
  final docDefaultsElement = _firstChildByLocalName(root, 'docDefaults');
  if (docDefaultsElement != null) {
    final rPrDefault = _firstChildByLocalName(docDefaultsElement, 'rPrDefault');
    final pPrDefault = _firstChildByLocalName(docDefaultsElement, 'pPrDefault');
    final runProps = _parseRunProperties(
      rPrDefault == null ? null : _firstChildByLocalName(rPrDefault, 'rPr'),
    );
    final paragraphProps = _parseParagraphSpacingProperties(
      pPrDefault == null ? null : _firstChildByLocalName(pPrDefault, 'pPr'),
    );
    docDefaults = _ResolvedParagraphStyle(
      isBold: runProps.isBold ?? false,
      isItalic: runProps.isItalic ?? false,
      isUnderlined: runProps.isUnderlined ?? false,
      colorHex: runProps.colorHex,
      fontSizePoints: runProps.fontSizePoints,
      spacingBeforePoints: paragraphProps.spacingBeforePoints ?? 0,
      spacingAfterPoints: paragraphProps.spacingAfterPoints ?? 0,
      keepWithNext: paragraphProps.keepWithNext ?? false,
    );
  }

  final rawStyles = <String, _RawParagraphStyle>{};
  for (final element in root.childElements) {
    if (element.name.local != 'style' ||
        _attributeValue(element, 'type') != 'paragraph') {
      continue;
    }
    final styleId = _attributeValue(element, 'styleId');
    if (styleId == null) {
      continue;
    }

    final basedOnElement = _firstChildByLocalName(element, 'basedOn');
    final runProps = _parseRunProperties(
      _firstChildByLocalName(element, 'rPr'),
    );
    final paragraphProps = _parseParagraphSpacingProperties(
      _firstChildByLocalName(element, 'pPr'),
    );

    rawStyles[styleId] = _RawParagraphStyle(
      basedOn: basedOnElement == null
          ? null
          : _attributeValue(basedOnElement, 'val'),
      isBold: runProps.isBold,
      isItalic: runProps.isItalic,
      isUnderlined: runProps.isUnderlined,
      colorHex: runProps.colorHex,
      fontSizePoints: runProps.fontSizePoints,
      spacingBeforePoints: paragraphProps.spacingBeforePoints,
      spacingAfterPoints: paragraphProps.spacingAfterPoints,
      keepWithNext: paragraphProps.keepWithNext,
    );
  }

  return _StylesTable(docDefaults: docDefaults, rawStyles: rawStyles);
}

bool _isEnabledProperty(XmlElement? property) {
  if (property == null) {
    return false;
  }

  final rawValue = _attributeValue(property, 'val')?.toLowerCase();
  return rawValue != 'false' && rawValue != '0';
}

bool _isUnderlineEnabled(XmlElement? property) {
  if (property == null) {
    return false;
  }

  final rawValue = _attributeValue(property, 'val')?.toLowerCase();
  return rawValue != 'none';
}

final class _SectionMetrics {
  const _SectionMetrics({
    required this.widthPoints,
    required this.heightPoints,
    required this.margins,
  });

  final double widthPoints;
  final double heightPoints;
  final DocumentMargins margins;
}

// Propiedades inline de un run individual. null = "no especificado en este
// run", para que el llamador haga cascada hacia el estilo del párrafo.
final class _RunStyle {
  const _RunStyle({
    this.isBold,
    this.isItalic,
    this.isUnderlined,
    this.colorHex,
    this.fontSizePoints,
    this.isHidden = false,
  });

  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderlined;
  final String? colorHex;
  final double? fontSizePoints;
  final bool isHidden;
}

final class _RunPropertiesRaw {
  const _RunPropertiesRaw({
    this.isBold,
    this.isItalic,
    this.isUnderlined,
    this.colorHex,
    this.fontSizePoints,
  });

  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderlined;
  final String? colorHex;
  final double? fontSizePoints;
}

final class _ParagraphPropertiesRaw {
  const _ParagraphPropertiesRaw({
    this.spacingBeforePoints,
    this.spacingAfterPoints,
    this.keepWithNext,
  });

  final double? spacingBeforePoints;
  final double? spacingAfterPoints;
  final bool? keepWithNext;
}

// Estilo de párrafo con nombre, tal como aparece en styles.xml, SIN resolver
// su cadena w:basedOn. null en un campo = ese estilo no lo define, hereda
// del padre en la cascada.
final class _RawParagraphStyle {
  const _RawParagraphStyle({
    this.basedOn,
    this.isBold,
    this.isItalic,
    this.isUnderlined,
    this.colorHex,
    this.fontSizePoints,
    this.spacingBeforePoints,
    this.spacingAfterPoints,
    this.keepWithNext,
  });

  final String? basedOn;
  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderlined;
  final String? colorHex;
  final double? fontSizePoints;
  final double? spacingBeforePoints;
  final double? spacingAfterPoints;
  final bool? keepWithNext;
}

// Estilo de párrafo YA resuelto (cascada docDefaults -> basedOn* -> estilo
// específico aplicada). Todos los campos concretos: bool con default false,
// spacing con default 0, colorHex/fontSizePoints null cuando ningún nivel de
// la cascada los definió (el renderer aplica su propio default en ese caso).
final class _ResolvedParagraphStyle {
  const _ResolvedParagraphStyle({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderlined = false,
    this.colorHex,
    this.fontSizePoints,
    this.spacingBeforePoints = 0,
    this.spacingAfterPoints = 0,
    this.keepWithNext = false,
  });

  final bool isBold;
  final bool isItalic;
  final bool isUnderlined;
  final String? colorHex;
  final double? fontSizePoints;
  final double spacingBeforePoints;
  final double spacingAfterPoints;
  final bool keepWithNext;
}

// Tabla de estilos de un documento: docDefaults ya resuelto + estilos con
// nombre sin resolver, resueltos bajo demanda y memoizados en `resolve`.
final class _StylesTable {
  _StylesTable({required this.docDefaults, required this._rawStyles});

  final _ResolvedParagraphStyle docDefaults;
  final Map<String, _RawParagraphStyle> _rawStyles;
  final Map<String, _ResolvedParagraphStyle> _cache =
      <String, _ResolvedParagraphStyle>{};

  // pStyleId null -> usa "Normal" si existe (el comportamiento por defecto
  // de OOXML para un párrafo sin w:pStyle explícito), o docDefaults si ni
  // siquiera hay un estilo "Normal" definido.
  _ResolvedParagraphStyle resolve(String? pStyleId) {
    final effectiveId =
        pStyleId ?? (_rawStyles.containsKey('Normal') ? 'Normal' : null);
    if (effectiveId == null) {
      return docDefaults;
    }

    final cached = _cache[effectiveId];
    if (cached != null) {
      return cached;
    }

    // Cadena w:basedOn del más específico al más lejano, con guardia
    // anti-ciclo y tope de profundidad: cadenas reales son 1-2 niveles, 5 es
    // margen amplio sin soportar herencia arbitrariamente larga.
    final chain = <_RawParagraphStyle>[];
    final visited = <String>{};
    var currentId = effectiveId;
    while (chain.length < 5 && visited.add(currentId)) {
      final raw = _rawStyles[currentId];
      if (raw == null) {
        break;
      }
      chain.add(raw);
      final basedOn = raw.basedOn;
      if (basedOn == null) {
        break;
      }
      currentId = basedOn;
    }

    var resolved = docDefaults;
    for (final raw in chain.reversed) {
      resolved = _ResolvedParagraphStyle(
        isBold: raw.isBold ?? resolved.isBold,
        isItalic: raw.isItalic ?? resolved.isItalic,
        isUnderlined: raw.isUnderlined ?? resolved.isUnderlined,
        colorHex: raw.colorHex ?? resolved.colorHex,
        fontSizePoints: raw.fontSizePoints ?? resolved.fontSizePoints,
        spacingBeforePoints:
            raw.spacingBeforePoints ?? resolved.spacingBeforePoints,
        spacingAfterPoints:
            raw.spacingAfterPoints ?? resolved.spacingAfterPoints,
        keepWithNext: raw.keepWithNext ?? resolved.keepWithNext,
      );
    }

    _cache[effectiveId] = resolved;
    return resolved;
  }
}

final class _ParagraphChunk {
  const _ParagraphChunk({
    required this.runs,
    required this.endsWithPageBreak,
    this.spacingBeforePoints = 0,
    this.spacingAfterPoints = 0,
    this.keepWithNext = false,
  });

  final _SerializedParagraph runs;
  final bool endsWithPageBreak;
  final double spacingBeforePoints;
  final double spacingAfterPoints;
  final bool keepWithNext;
}

final class _SerializedBlockSegment {
  const _SerializedBlockSegment({
    required this.block,
    required this.endsWithPageBreak,
  });

  final _SerializedBlock block;
  final bool endsWithPageBreak;
}
