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
const _defaultHeaderFooterDistancePoints = 36.0;
const _twipsPerPoint = 20.0;
// English Metric Units: 914400 por pulgada, 72 puntos por pulgada.
const _emuPerPoint = 12700.0;
// Un `w:line` con lineRule="auto" viene en 240avos de línea (240 = sencillo).
const _twentiethsPerLine = 240.0;
// Grosor de borde de tabla en `w:sz`: octavos de punto.
const _eighthsPerPoint = 8.0;

// ponytail: estimación heurística por caracteres/líneas, NO reflow real.
// Solo se usa para rellenar tramos del documento sin ningún marcador de
// salto explícito. Fuente de cuerpo asumida ~11pt — el "Normal" por defecto
// de Word/Office modernos — cuando el párrafo no declara tamaño propio.
// Techo conocido: sin métricas de fuente reales esto puede sobre/sub-estimar
// cuánto contenido cabe por página; es un relleno de huecos, no un motor
// tipográfico. Mejora futura: medir con las métricas reales de la fuente.
const _estimatedFontSizePoints = 11.0;
// Alto natural de línea de una fuente proporcional típica de Windows
// (Calibri 1.22em, Cambria 1.17em, Times New Roman 1.15em) sobre el que Word
// aplica el multiplicador de interlineado. 1.17 es el promedio medido
// (FontFamily.GetLineSpacing/GetEmHeight) de Calibri/Cambria/Times New
// Roman/Arial; el valor anterior (1.2) pesaba de más hacia Calibri y
// sobreestimaba el alto de línea en cuerpos de texto con Cambria o Times.
const _naturalLineHeightRatio = 1.17;
// Ancho promedio de carácter como fracción del tamaño de fuente. 0.44 es el
// promedio medido (Graphics.MeasureString sobre texto de contrato real en
// español) para Calibri/Cambria/Times New Roman/Arial a 11pt; el valor
// anterior (0.5) sobreestimaba el ancho y por tanto subestimaba cuántos
// caracteres caben por línea.
const _charWidthRatio = 0.44;

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

  final themeFonts = _parseThemeFonts(archiveEntries);
  final stylesTable = _parseStylesTable(archiveEntries, themeFonts);

  final documentXml = _archiveEntryAsString(
    archiveEntries['word/document.xml']!,
  );
  final document = _parseDocumentXml(documentXml);
  final body = _findBody(document);
  final sectionProperties = _findSectionProperties(body);
  final sectionMetrics = _parseSectionMetrics(sectionProperties);

  final bodyContext = _ParseContext(
    archiveEntries: archiveEntries,
    relationships: _parsePartRelationships(archiveEntries, 'word/document.xml'),
    stylesTable: stylesTable,
    omissions: omissions,
  );
  final pages = _extractPages(body, bodyContext, sectionMetrics);

  final headerSegments = _resolveSectionReferenceBlocks(
    sectionProperties,
    bodyContext,
    referenceLocalName: 'headerReference',
  );
  final footerSegments = _resolveSectionReferenceBlocks(
    sectionProperties,
    bodyContext,
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
      'headerDistancePoints': sectionMetrics.margins.headerDistancePoints,
      'footerDistancePoints': sectionMetrics.margins.footerDistancePoints,
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
    headerDistancePoints: _asDouble(
      marginsMap['headerDistancePoints'],
      _defaultHeaderFooterDistancePoints,
    ),
    footerDistancePoints: _asDouble(
      marginsMap['footerDistancePoints'],
      _defaultHeaderFooterDistancePoints,
    ),
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
    return DocumentBlock.table(_tableFromPayload(blockMap));
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
      alignment: _alignmentFromName(blockMap['alignment']),
      indentLeftPoints: _asDouble(blockMap['indentLeftPoints'], 0),
      indentRightPoints: _asDouble(blockMap['indentRightPoints'], 0),
      indentFirstLinePoints: _asDouble(blockMap['indentFirstLinePoints'], 0),
      lineSpacingMultiple: _asNullableDouble(blockMap['lineSpacingMultiple']),
      lineSpacingExactPoints: _asNullableDouble(
        blockMap['lineSpacingExactPoints'],
      ),
    ),
  );
}

DocumentTable _tableFromPayload(Map<Object?, Object?> blockMap) {
  final rowsRaw = blockMap['rows'];
  final rowsList = rowsRaw is List<Object?> ? rowsRaw : const <Object?>[];
  final columnsRaw = blockMap['columnWidthsPoints'];
  final columnsList = columnsRaw is List<Object?>
      ? columnsRaw
      : const <Object?>[];

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
                widthPoints: _asNullableDouble(_cellWidthRaw(cellRaw)),
              ),
          ],
        ),
    ],
    columnWidthsPoints: <double>[
      for (final widthRaw in columnsList) _asDouble(widthRaw, 0),
    ],
    alignment: _alignmentFromName(blockMap['alignment']),
    borderWidthPoints: _asDouble(blockMap['borderWidthPoints'], 0),
    borderColorHex: blockMap['borderColorHex'] as String?,
  );
}

DocumentAlignment _alignmentFromName(Object? raw) {
  for (final alignment in DocumentAlignment.values) {
    if (alignment.name == raw) {
      return alignment;
    }
  }
  return DocumentAlignment.start;
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

Object? _cellWidthRaw(Object? cellRaw) {
  final cellMap = cellRaw is Map<Object?, Object?>
      ? cellRaw
      : const <Object?, Object?>{};
  return cellMap['widthPoints'];
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
    fontFamily: runMap['fontFamily'] as String?,
    image: _imageFromPayload(runMap['image']),
  );
}

DocumentImage? _imageFromPayload(Object? imageRaw) {
  if (imageRaw is! Map<Object?, Object?>) {
    return null;
  }
  final bytes = imageRaw['bytes'];
  if (bytes is! Uint8List) {
    return null;
  }
  return DocumentImage(
    bytes: bytes,
    widthPoints: _asDouble(imageRaw['widthPoints'], 0),
    heightPoints: _asDouble(imageRaw['heightPoints'], 0),
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

Uint8List? _archiveEntryAsBytes(ArchiveFile file) {
  final content = file.content;
  if (content is Uint8List) {
    return content;
  }
  if (content is List<int>) {
    return Uint8List.fromList(content);
  }
  return null;
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
      headerDistancePoints: _pointsFromTwipsAttribute(
        pageMargins,
        attributeLocalName: 'header',
        fallback: _defaultHeaderFooterDistancePoints,
      ),
      footerDistancePoints: _pointsFromTwipsAttribute(
        pageMargins,
        attributeLocalName: 'footer',
        fallback: _defaultHeaderFooterDistancePoints,
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
  _ParseContext bodyContext, {
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

  final target = bodyContext.relationships[relationshipId];
  if (target == null) {
    return null;
  }

  final entry = bodyContext.archiveEntries[target];
  if (entry == null) {
    return null;
  }

  XmlDocument parsed;
  try {
    parsed = XmlDocument.parse(_archiveEntryAsString(entry));
  } catch (_) {
    return null;
  }

  // Las imágenes del encabezado/pie se referencian desde el .rels de SU
  // propia parte (word/_rels/header1.xml.rels), no desde el de document.xml.
  return _parseContainerBlocks(
    parsed.rootElement,
    bodyContext.withRelationships(
      _parsePartRelationships(bodyContext.archiveEntries, target),
    ),
  );
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

/// Índice `rId -> ruta normalizada dentro del ZIP` del `.rels` de [partPath].
///
/// Los `Target` son relativos a la carpeta de la parte, así que
/// `media/image1.png` referenciado desde `word/header1.xml` resuelve a
/// `word/media/image1.png`. Las relaciones externas (`TargetMode="External"`)
/// se descartan: apuntan fuera del paquete y no hay bytes que extraer.
Map<String, String> _parsePartRelationships(
  Map<String, ArchiveFile> archiveEntries,
  String partPath,
) {
  final directory = p.url.dirname(partPath);
  final fileName = p.url.basename(partPath);
  final relsPath = p.url
      .join(directory, '_rels', '$fileName.rels')
      .toLowerCase();
  final entry = archiveEntries[relsPath];
  if (entry == null) {
    return const <String, String>{};
  }

  XmlDocument relsDocument;
  try {
    relsDocument = XmlDocument.parse(_archiveEntryAsString(entry));
  } catch (_) {
    return const <String, String>{};
  }

  final relationships = <String, String>{};
  for (final relationship in relsDocument.descendants.whereType<XmlElement>()) {
    if (relationship.name.local != 'Relationship') {
      continue;
    }
    if (_attributeValue(relationship, 'TargetMode') == 'External') {
      continue;
    }
    final id = _attributeValue(relationship, 'Id');
    final target = _attributeValue(relationship, 'Target');
    if (id == null || target == null || target.isEmpty) {
      continue;
    }
    relationships[id] = p.url
        .normalize(
          target.startsWith('/')
              ? target.substring(1)
              : p.url.join(directory, target),
        )
        .toLowerCase();
  }
  return relationships;
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
// fin de sección intermedia). Si el documento trae al menos un
// `w:lastRenderedPageBreak`, Word ya nos dijo dónde termina CADA página y la
// heurística se apaga por completo: estimar encima de un dato real solo
// puede corromperlo (partía cláusulas que en Word caben enteras). La
// heurística de caracteres/líneas (ver constantes `_estimated*`) queda como
// relleno SOLO para documentos sin ningún marcador — nunca maquetados por
// Word, o nuestra propia salida exportada — para que texto continuo largo no
// colapse en una sola página kilométrica.
//
// La detección es de documento completo, no por sección: Word escribe estos
// marcadores en una única pasada de maquetación sobre todo el body, así que
// un documento los tiene todos o no tiene ninguno; distinguir por sección
// añadiría estado sin cambiar el resultado. Los marcadores de dentro de una
// tabla NO cuentan: se ignoran al paginar (ver `_isInsideTable`), así que un
// documento cuyos únicos marcadores estén en tablas no ha aportado ninguna
// señal utilizable y debe conservar el relleno heurístico. Sigue sin
// reproducirse el reflow automático de Word, que requeriría un motor
// tipográfico OOXML completo.
List<_SerializedPage> _extractPages(
  XmlElement body,
  _ParseContext context,
  _SectionMetrics sectionMetrics,
) {
  final pages = <_SerializedPage>[];
  var currentPageBlocks = <_SerializedBlock>[];
  var currentPageHeightPoints = 0.0;

  final hasRenderedPageBreaks = body.descendants.whereType<XmlElement>().any(
    (element) =>
        element.name.local == 'lastRenderedPageBreak' &&
        !_isInsideTable(element),
  );

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
    context,
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
    if (!hasRenderedPageBreaks &&
        currentPageBlocks.isNotEmpty &&
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
// before/after, con el interlineado y el tamaño de fuente REALES del párrafo
// cuando el DOCX los declara. Una imagen aporta su alto propio. Tablas: una
// línea por fila al tamaño de cuerpo asumido (sin layout de columnas real) —
// techo aceptado, ver comentario de `_serializeTable` sobre gridSpan/vMerge.
double _estimatedSegmentHeightPoints(
  _SerializedBlock block,
  double contentWidthPoints,
) {
  if (block['kind'] == 'table') {
    final rows = block['rows'];
    final rowCount = rows is List<Object?> && rows.isNotEmpty ? rows.length : 1;
    return rowCount * _estimatedFontSizePoints * _naturalLineHeightRatio;
  }

  final fontSizePoints = _blockFontSizePoints(block);
  final exactLinePoints = _asNullableDouble(block['lineSpacingExactPoints']);
  final lineMultiple = _asDouble(block['lineSpacingMultiple'], 1);
  final lineHeightPoints =
      exactLinePoints ??
      fontSizePoints * _naturalLineHeightRatio * lineMultiple;
  final charWidthPoints = fontSizePoints * _charWidthRatio;
  final indentPoints =
      _asDouble(block['indentLeftPoints'], 0) +
      _asDouble(block['indentRightPoints'], 0);
  final availableWidthPoints = math.max(
    charWidthPoints,
    contentWidthPoints - indentPoints,
  );
  final charsPerLine = math.max(1, availableWidthPoints / charWidthPoints);

  final runsRaw = block['runs'];
  final runs = runsRaw is List<Object?> ? runsRaw : const <Object?>[];
  var textLength = 0;
  var imageHeightPoints = 0.0;
  for (final runRaw in runs) {
    if (runRaw is! Map<String, Object?>) {
      continue;
    }
    final text = runRaw['text'];
    if (text is String) {
      textLength += text.length;
    }
    final image = runRaw['image'];
    if (image is Map<String, Object?>) {
      imageHeightPoints = math.max(
        imageHeightPoints,
        _asDouble(image['heightPoints'], 0),
      );
    }
  }

  final lines = textLength == 0
      ? 1
      : math.max(1, (textLength / charsPerLine).ceil());

  final spacingBeforePoints = _asDouble(block['spacingBeforePoints'], 0);
  final spacingAfterPoints = _asDouble(block['spacingAfterPoints'], 0);

  return math.max(lines * lineHeightPoints, imageHeightPoints) +
      spacingBeforePoints +
      spacingAfterPoints;
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
  _ParseContext context, {
  bool respectPageBreakBefore = false,
}) {
  final segments = <_SerializedBlockSegment>[];
  // `w:contextualSpacing` suprime el espacio entre párrafos consecutivos del
  // MISMO estilo (lo que Word muestra como "No agregar espacio entre
  // párrafos del mismo estilo"). Se resuelve aquí, donde los hermanos son
  // visibles, para no arrastrar el estilo hasta el renderer.
  final paragraphStyles = <int, _ResolvedParagraphStyle>{};
  final paragraphStyleIds = <int, String?>{};

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

      final styleId = _paragraphStyleId(child);
      final paragraphStyle = _resolveParagraphStyle(child, context);
      final chunks = _splitParagraphByPageBreak(child, context, paragraphStyle);
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
        paragraphStyles[segments.length] = paragraphStyle;
        paragraphStyleIds[segments.length] = styleId;
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
              'alignment': paragraphStyle.alignment.name,
              'indentLeftPoints': paragraphStyle.indentLeftPoints,
              'indentRightPoints': paragraphStyle.indentRightPoints,
              'indentFirstLinePoints': paragraphStyle.indentFirstLinePoints,
              'lineSpacingMultiple': paragraphStyle.lineSpacingMultiple,
              'lineSpacingExactPoints': paragraphStyle.lineSpacingExactPoints,
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
          block: _serializeTable(child, context),
          endsWithPageBreak: false,
        ),
      );
    }
  }

  _applyContextualSpacing(segments, paragraphStyles, paragraphStyleIds);
  return segments;
}

void _applyContextualSpacing(
  List<_SerializedBlockSegment> segments,
  Map<int, _ResolvedParagraphStyle> styles,
  Map<int, String?> styleIds,
) {
  for (final entry in styles.entries) {
    final index = entry.key;
    if (!entry.value.contextualSpacing) {
      continue;
    }

    final suppressBefore = index > 0 && styleIds[index - 1] == styleIds[index];
    final suppressAfter =
        index < segments.length - 1 && styleIds[index + 1] == styleIds[index];
    if (!suppressBefore && !suppressAfter) {
      continue;
    }

    final block = <String, Object?>{...segments[index].block};
    if (suppressBefore) {
      block['spacingBeforePoints'] = 0.0;
    }
    if (suppressAfter) {
      block['spacingAfterPoints'] = 0.0;
    }
    segments[index] = _SerializedBlockSegment(
      block: block,
      endsWithPageBreak: segments[index].endsWithPageBreak,
    );
  }
}

_SerializedBlock _serializeTable(
  XmlElement tableElement,
  _ParseContext context,
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

      final nestedSegments = _parseContainerBlocks(cellElement, context);
      cells.add(<String, Object?>{
        'blocks': <Object?>[
          for (final segment in nestedSegments)
            <String, Object?>{...segment.block},
        ],
        'widthPoints': _cellWidthPoints(cellElement),
      });
    }

    rows.add(<String, Object?>{'cells': cells});
  }

  final tableProperties = _firstChildByLocalName(tableElement, 'tblPr');
  final borders = _resolveTableBorders(tableProperties, context.stylesTable);

  return <String, Object?>{
    'kind': 'table',
    'rows': rows,
    'columnWidthsPoints': _tableGridWidthsPoints(tableElement),
    'alignment': _tableAlignment(tableProperties).name,
    'borderWidthPoints': borders.widthPoints,
    'borderColorHex': borders.colorHex,
  };
}

List<Object?> _tableGridWidthsPoints(XmlElement tableElement) {
  final grid = _firstChildByLocalName(tableElement, 'tblGrid');
  if (grid == null) {
    return const <Object?>[];
  }

  return <Object?>[
    for (final column in grid.childElements)
      if (column.name.local == 'gridCol')
        _pointsFromTwipsAttribute(column, attributeLocalName: 'w', fallback: 0),
  ];
}

double? _cellWidthPoints(XmlElement cellElement) {
  final cellProperties = _firstChildByLocalName(cellElement, 'tcPr');
  if (cellProperties == null) {
    return null;
  }
  final width = _firstChildByLocalName(cellProperties, 'tcW');
  if (width == null || _attributeValue(width, 'type') != 'dxa') {
    return null;
  }
  final twips = int.tryParse(_attributeValue(width, 'w') ?? '');
  return twips == null ? null : twips / _twipsPerPoint;
}

DocumentAlignment _tableAlignment(XmlElement? tableProperties) {
  if (tableProperties == null) {
    return DocumentAlignment.start;
  }
  final justification = _firstChildByLocalName(tableProperties, 'jc');
  if (justification == null) {
    return DocumentAlignment.start;
  }
  return _parseAlignment(_attributeValue(justification, 'val')) ??
      DocumentAlignment.start;
}

// Word solo dibuja los bordes de una tabla cuando `w:tblBorders` los declara
// (directamente o vía el estilo de tabla en `w:tblStyle`). Sin ellos la tabla
// es invisible salvo por su contenido — dibujar una retícula ahí sería
// inventar tinta que Word no pone.
_TableBorders _resolveTableBorders(
  XmlElement? tableProperties,
  _StylesTable stylesTable,
) {
  if (tableProperties == null) {
    return const _TableBorders();
  }

  final direct = _parseTableBorders(
    _firstChildByLocalName(tableProperties, 'tblBorders'),
  );
  if (direct.widthPoints > 0) {
    return direct;
  }

  final styleElement = _firstChildByLocalName(tableProperties, 'tblStyle');
  final styleId = styleElement == null
      ? null
      : _attributeValue(styleElement, 'val');
  if (styleId == null) {
    return direct;
  }
  return stylesTable.resolveTableBorders(styleId);
}

_TableBorders _parseTableBorders(XmlElement? borders) {
  if (borders == null) {
    return const _TableBorders();
  }

  for (final side in borders.childElements) {
    final value = _attributeValue(side, 'val');
    if (value == null || value == 'none' || value == 'nil') {
      continue;
    }
    final eighths = int.tryParse(_attributeValue(side, 'sz') ?? '');
    return _TableBorders(
      // Word admite `w:sz` ausente (por defecto 0.5pt) y trata 0 como hairline.
      widthPoints: eighths == null || eighths == 0
          ? 0.5
          : eighths / _eighthsPerPoint,
      colorHex: _colorHexFromAttribute(_attributeValue(side, 'color')),
    );
  }
  return const _TableBorders();
}

// Resuelve el estilo del párrafo una sola vez y lo aplica en cascada: cada
// run gana con su propia propiedad inline (w:b/w:i/w:u/w:color/w:sz/w:rFonts)
// cuando la tiene, si no hereda del estilo de carácter (w:rStyle) y en último
// lugar del párrafo. El spacing before/after y keepWithNext del párrafo se
// atan al PRIMER/ÚLTIMO chunk respectivamente — un párrafo solo se fragmenta
// en varios chunks cuando trae un salto de página explícito en medio, caso
// raro; en el caso común (un solo chunk) ambos caen en el mismo chunk, que es
// lo correcto.
List<_ParagraphChunk> _splitParagraphByPageBreak(
  XmlElement paragraph,
  _ParseContext context,
  _ResolvedParagraphStyle paragraphStyle,
) {
  final rawChunks = _collectRawParagraphChunks(
    paragraph,
    context,
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

/// Cascada completa del párrafo: docDefaults -> cadena `w:basedOn` del estilo
/// con nombre -> formato directo del propio `w:pPr`.
_ResolvedParagraphStyle _resolveParagraphStyle(
  XmlElement paragraph,
  _ParseContext context,
) {
  final named = context.stylesTable.resolve(_paragraphStyleId(paragraph));
  final paragraphProperties = _firstChildByLocalName(paragraph, 'pPr');
  if (paragraphProperties == null) {
    return named;
  }

  return named.mergeWith(
    paragraphProperties: _parseParagraphProperties(paragraphProperties),
    // `w:pPr/w:rPr` describe la marca de párrafo (¶), no sus runs: Word no
    // la propaga al texto, así que aquí tampoco.
    runProperties: const _RunPropertiesRaw(),
  );
}

List<_ParagraphChunk> _collectRawParagraphChunks(
  XmlElement paragraph,
  _ParseContext context,
  _ResolvedParagraphStyle paragraphStyle,
) {
  final chunks = <_ParagraphChunk>[];
  var currentRuns = <_SerializedRun>[];
  var sawVisibleToken = false;
  var endedWithPageBreak = false;
  // Un `DocumentTableBlock` es atómico: se exporta y se pinta entero, así que
  // no puede repartirse entre dos páginas. Trocear el párrafo de una celda
  // por un salto interno solo añadía bloques vacíos y una página en blanco
  // detrás de la tabla, sin partir nada de verdad.
  final ignorePageBreaks = _isInsideTable(paragraph);

  final runElements = paragraph.descendants.whereType<XmlElement>().where(
    (element) =>
        element.name.local == 'r' &&
        !_isOutsideParagraphFlow(element, paragraph),
  );

  for (final run in runElements) {
    if (_hasDeletedChangeAncestor(run)) {
      continue;
    }

    final runStyle = _resolveRunStyle(run, context, paragraphStyle);
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
          'isBold': runStyle.isBold,
          'isItalic': runStyle.isItalic,
          'isUnderlined': runStyle.isUnderlined,
          'colorHex': runStyle.colorHex,
          'fontSizePoints': runStyle.fontSizePoints,
          'fontFamily': runStyle.fontFamily,
        },
      ];
      sawVisibleToken = true;
      endedWithPageBreak = false;
    }

    for (final element in _runContentElements(run)) {
      final localName = element.name.local;

      if (localName == 'drawing' || localName == 'pict') {
        final image = _resolveImage(element, context);
        if (image == null) {
          context.omissions.add(DocumentOmission.image);
          continue;
        }

        flushRunText();
        currentRuns = <_SerializedRun>[
          ...currentRuns,
          <String, Object?>{
            'text': '',
            'isBold': runStyle.isBold,
            'isItalic': runStyle.isItalic,
            'isUnderlined': runStyle.isUnderlined,
            'colorHex': runStyle.colorHex,
            'fontSizePoints': runStyle.fontSizePoints,
            'fontFamily': runStyle.fontFamily,
            'image': image,
          },
        ];
        sawVisibleToken = true;
        endedWithPageBreak = false;
        continue;
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
          if (!ignorePageBreaks) {
            flushRunText();
            chunks.add(
              _ParagraphChunk(runs: currentRuns, endsWithPageBreak: true),
            );
            currentRuns = <_SerializedRun>[];
            sawVisibleToken = true;
            endedWithPageBreak = true;
          }
        } else {
          runText.write('\n');
          sawVisibleToken = true;
          endedWithPageBreak = false;
        }
        continue;
      }
      // `w:lastRenderedPageBreak` es el ÚNICO registro de dónde el motor de
      // maquetación de Word cortó cada página. Los marcadores rancios de un
      // documento reescrito sin re-maquetar se resuelven en origen: el
      // exportador los elimina al escribir el DOCX.
      if (localName == 'lastRenderedPageBreak' && !ignorePageBreaks) {
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

/// Contenido de un `w:r` en orden de documento, sin entrar en los hijos de un
/// `w:drawing`/`w:pict`: el texto de un cuadro de texto incrustado pertenece
/// al cuadro, no al flujo del párrafo que lo contiene.
///
/// Debe mantenerse alineado con `_splitParagraphChunks` de
/// `docx_zip_exporter.dart`: si un lado incluye texto que el otro no, los
/// offsets del mapeo dejan de apuntar al mismo sitio al exportar.
Iterable<XmlElement> _runContentElements(XmlElement run) sync* {
  for (final child in run.childElements) {
    final localName = child.name.local;
    // `mc:Fallback` es la versión VML alternativa del mismo contenido que ya
    // trae `mc:Choice`: recorrerla duplicaría imágenes y texto.
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

/// Un `w:r` que cuelga de un dibujo, de un cuadro de texto o de la rama
/// `mc:Fallback` no pertenece al flujo de [paragraph] aunque `descendants` lo
/// encuentre por debajo de él.
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

/// Extrae los bytes y el tamaño de un `w:drawing` (DrawingML) o `w:pict`
/// (VML heredado). Retorna null cuando la imagen no se puede resolver
/// (relación externa, parte ausente o sin dimensiones declaradas): el
/// llamador registra entonces la omisión honesta.
Map<String, Object?>? _resolveImage(
  XmlElement container,
  _ParseContext context,
) {
  final relationshipId = _imageRelationshipId(container);
  if (relationshipId == null) {
    return null;
  }

  final target = context.relationships[relationshipId];
  if (target == null) {
    return null;
  }

  final entry = context.archiveEntries[target];
  if (entry == null) {
    return null;
  }

  final bytes = _archiveEntryAsBytes(entry);
  if (bytes == null || bytes.isEmpty) {
    return null;
  }

  final size = _imageSizePoints(container);
  if (size == null) {
    return null;
  }

  return <String, Object?>{
    'bytes': bytes,
    'widthPoints': size.width,
    'heightPoints': size.height,
  };
}

String? _imageRelationshipId(XmlElement container) {
  for (final element in container.descendants.whereType<XmlElement>()) {
    final localName = element.name.local;
    // DrawingML: <a:blip r:embed="rIdN" />.
    if (localName == 'blip') {
      final embed = _attributeValue(element, 'embed');
      if (embed != null && embed.isNotEmpty) {
        return embed;
      }
    }
    // VML heredado: <v:imagedata r:id="rIdN" />.
    if (localName == 'imagedata') {
      final id = _attributeValue(element, 'id');
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }
  }
  return null;
}

_ImageSize? _imageSizePoints(XmlElement container) {
  // `wp:extent` es el tamaño con el que Word dibuja la imagen en la página;
  // `a:ext` dentro de pic:spPr es el del recuadro del gráfico y sirve de
  // respaldo cuando el primero falta.
  for (final localName in const <String>['extent', 'ext']) {
    for (final element in container.descendants.whereType<XmlElement>()) {
      if (element.name.local != localName) {
        continue;
      }
      final width = int.tryParse(_attributeValue(element, 'cx') ?? '');
      final height = int.tryParse(_attributeValue(element, 'cy') ?? '');
      if (width == null || height == null || width <= 0 || height <= 0) {
        continue;
      }
      return _ImageSize(width / _emuPerPoint, height / _emuPerPoint);
    }
  }

  return _vmlShapeSizePoints(container);
}

// VML: <v:shape style="width:75.75pt;height:33pt" />.
_ImageSize? _vmlShapeSizePoints(XmlElement container) {
  for (final element in container.descendants.whereType<XmlElement>()) {
    final style = _attributeValue(element, 'style');
    if (style == null) {
      continue;
    }

    double? width;
    double? height;
    for (final declaration in style.split(';')) {
      final separator = declaration.indexOf(':');
      if (separator < 0) {
        continue;
      }
      final property = declaration.substring(0, separator).trim().toLowerCase();
      final value = declaration.substring(separator + 1).trim();
      if (property == 'width') {
        width = _cssLengthPoints(value);
      } else if (property == 'height') {
        height = _cssLengthPoints(value);
      }
    }

    if (width != null && height != null && width > 0 && height > 0) {
      return _ImageSize(width, height);
    }
  }
  return null;
}

double? _cssLengthPoints(String value) {
  const unitsPerPoint = <String, double>{
    'pt': 1,
    'px': 0.75,
    'in': 72,
    'cm': 72 / 2.54,
    'mm': 7.2 / 2.54,
    'pc': 12,
  };

  for (final unit in unitsPerPoint.entries) {
    if (value.endsWith(unit.key)) {
      final amount = double.tryParse(
        value.substring(0, value.length - unit.key.length).trim(),
      );
      return amount == null ? null : amount * unit.value;
    }
  }
  return double.tryParse(value);
}

bool _hasDeletedChangeAncestor(XmlElement run) {
  for (final ancestor in run.ancestors.whereType<XmlElement>()) {
    if (ancestor.name.local == 'del') return true;
  }
  return false;
}

bool _isPageBreak(XmlElement breakElement) {
  final breakType = _attributeValue(breakElement, 'type');
  return breakType == 'page';
}

/// `true` si [element] cuelga de una celda de tabla (`w:tc`), a cualquier
/// profundidad — también en tablas anidadas.
///
/// Un `DocumentTableBlock` es indivisible: se pinta y se exporta entero, así
/// que un salto de página interno no puede partirlo. Ignorarlo evita los
/// bloques vacíos y la página en blanco que aparecían detrás de una tabla que
/// Word sí reparte entre dos páginas.
///
/// Debe mantenerse alineado con el `_isInsideTable` de
/// `docx_zip_exporter.dart`: si un lado trocea el párrafo de una celda y el
/// otro no, los índices de bloque de celda dejan de coincidir y el mapeo
/// escribe en el sitio equivocado al exportar.
bool _isInsideTable(XmlElement element) {
  for (final ancestor in element.ancestors.whereType<XmlElement>()) {
    if (ancestor.name.local == 'tc') {
      return true;
    }
  }
  return false;
}

bool _hasPageBreakBefore(XmlElement paragraph) {
  final paragraphProperties = _firstChildByLocalName(paragraph, 'pPr');
  if (paragraphProperties == null) {
    return false;
  }

  return _isEnabledProperty(
    _firstChildByLocalName(paragraphProperties, 'pageBreakBefore'),
  );
}

// ponytail: un sectPr hijo directo de pPr marca el fin de una sección
// intermedia (el sectPr final del documento es hijo directo de body, y ese
// ya se maneja aparte en `_findSectionProperties`). Por spec OOXML el salto
// de sección siempre implica salto de página salvo `w:type` "continuous" o
// "nextColumn"; la ausencia de `w:type` es el default "nextPage", que SÍ
// rompe página.
bool _paragraphSectionBreakEndsPage(XmlElement paragraph) {
  final paragraphProperties = _firstChildByLocalName(paragraph, 'pPr');
  if (paragraphProperties == null) {
    return false;
  }

  final sectionProperties = _firstChildByLocalName(
    paragraphProperties,
    'sectPr',
  );
  if (sectionProperties == null) {
    return false;
  }

  final sectionType = _firstChildByLocalName(sectionProperties, 'type');
  if (sectionType == null) {
    return true;
  }

  final typeValue = _attributeValue(sectionType, 'val');
  return typeValue != 'continuous' && typeValue != 'nextColumn';
}

_RunStyle _resolveRunStyle(
  XmlElement run,
  _ParseContext context,
  _ResolvedParagraphStyle paragraphStyle,
) {
  final runProperties = _firstChildByLocalName(run, 'rPr');
  final inline = _parseRunProperties(runProperties);
  final characterStyle = context.stylesTable.resolveCharacterStyle(
    _characterStyleId(runProperties),
  );
  final hasVanish =
      runProperties != null &&
      _firstChildByLocalName(runProperties, 'vanish') != null;

  return _RunStyle(
    isBold: inline.isBold ?? characterStyle.isBold ?? paragraphStyle.isBold,
    isItalic:
        inline.isItalic ?? characterStyle.isItalic ?? paragraphStyle.isItalic,
    isUnderlined:
        inline.isUnderlined ??
        characterStyle.isUnderlined ??
        paragraphStyle.isUnderlined,
    colorHex:
        inline.colorHex ?? characterStyle.colorHex ?? paragraphStyle.colorHex,
    fontSizePoints:
        inline.fontSizePoints ??
        characterStyle.fontSizePoints ??
        paragraphStyle.fontSizePoints,
    fontFamily:
        inline.fontFamily ??
        characterStyle.fontFamily ??
        paragraphStyle.fontFamily,
    isHidden: hasVanish,
  );
}

String? _characterStyleId(XmlElement? runProperties) {
  if (runProperties == null) {
    return null;
  }
  final rStyle = _firstChildByLocalName(runProperties, 'rStyle');
  if (rStyle == null) {
    return null;
  }
  return _attributeValue(rStyle, 'val');
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
_RunPropertiesRaw _parseRunProperties(
  XmlElement? rPr, {
  _ThemeFonts themeFonts = const _ThemeFonts(),
}) {
  if (rPr == null) {
    return const _RunPropertiesRaw();
  }

  bool? isBold;
  bool? isItalic;
  bool? isUnderlined;
  String? colorHex;
  double? fontSizePoints;
  String? fontFamily;

  for (final property in rPr.childElements) {
    switch (property.name.local) {
      case 'b':
        isBold = _isEnabledProperty(property);
      case 'i':
        isItalic = _isEnabledProperty(property);
      case 'u':
        isUnderlined = _isUnderlineEnabled(property);
      case 'color':
        colorHex = _colorHexFromAttribute(_attributeValue(property, 'val'));
      case 'sz':
        fontSizePoints = _fontSizePointsFromProperty(property);
      case 'rFonts':
        fontFamily = _fontFamilyFromProperty(property, themeFonts);
    }
  }

  return _RunPropertiesRaw(
    isBold: isBold,
    isItalic: isItalic,
    isUnderlined: isUnderlined,
    colorHex: colorHex,
    fontSizePoints: fontSizePoints,
    fontFamily: fontFamily,
  );
}

String? _colorHexFromAttribute(String? value) {
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

// `w:rFonts` puede nombrar la fuente directamente (`w:ascii`) o delegarla al
// tema del documento (`w:asciiTheme="minorHAnsi"`), que es lo que hace Word
// por defecto: sin resolver el tema, el cuerpo del documento se renderiza con
// una fuente que no es la que el usuario ve en Word.
String? _fontFamilyFromProperty(XmlElement rFonts, _ThemeFonts themeFonts) {
  final explicit =
      _attributeValue(rFonts, 'ascii') ?? _attributeValue(rFonts, 'hAnsi');
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  final theme =
      _attributeValue(rFonts, 'asciiTheme') ??
      _attributeValue(rFonts, 'hAnsiTheme');
  if (theme == null) {
    return null;
  }
  if (theme.startsWith('major')) {
    return themeFonts.majorLatin;
  }
  if (theme.startsWith('minor')) {
    return themeFonts.minorLatin;
  }
  return null;
}

// Parseo compartido de un `<w:pPr>` para las propiedades que participan en
// la cascada de estilos de párrafo. Igual que `_parseRunProperties`:
// null = "no especificado aquí".
_ParagraphPropertiesRaw _parseParagraphProperties(XmlElement? pPr) {
  if (pPr == null) {
    return const _ParagraphPropertiesRaw();
  }

  double? spacingBeforePoints;
  double? spacingAfterPoints;
  double? lineSpacingMultiple;
  double? lineSpacingExactPoints;
  bool? keepWithNext;
  bool? contextualSpacing;
  DocumentAlignment? alignment;
  double? indentLeftPoints;
  double? indentRightPoints;
  double? indentFirstLinePoints;

  for (final property in pPr.childElements) {
    switch (property.name.local) {
      case 'spacing':
        final beforeTwips = int.tryParse(
          _attributeValue(property, 'before') ?? '',
        );
        final afterTwips = int.tryParse(
          _attributeValue(property, 'after') ?? '',
        );
        if (beforeTwips != null) {
          spacingBeforePoints = beforeTwips / _twipsPerPoint;
        }
        if (afterTwips != null) {
          spacingAfterPoints = afterTwips / _twipsPerPoint;
        }
        final line = int.tryParse(_attributeValue(property, 'line') ?? '');
        if (line != null && line > 0) {
          // "auto" (el valor por defecto) mide en 240avos de línea; "exact" y
          // "atLeast" miden en twips. atLeast se trata como exacto: el alto
          // mínimo coincide con el real salvo contenido sobredimensionado.
          final rule = _attributeValue(property, 'lineRule') ?? 'auto';
          if (rule == 'auto') {
            lineSpacingMultiple = line / _twentiethsPerLine;
          } else {
            lineSpacingExactPoints = line / _twipsPerPoint;
          }
        }
      case 'keepNext':
        keepWithNext = _isEnabledProperty(property);
      case 'contextualSpacing':
        contextualSpacing = _isEnabledProperty(property);
      case 'jc':
        alignment = _parseAlignment(_attributeValue(property, 'val'));
      case 'ind':
        final left =
            _attributeValue(property, 'left') ??
            _attributeValue(property, 'start');
        final right =
            _attributeValue(property, 'right') ??
            _attributeValue(property, 'end');
        final firstLine = _attributeValue(property, 'firstLine');
        final hanging = _attributeValue(property, 'hanging');
        final leftTwips = int.tryParse(left ?? '');
        final rightTwips = int.tryParse(right ?? '');
        final firstLineTwips = int.tryParse(firstLine ?? '');
        final hangingTwips = int.tryParse(hanging ?? '');
        if (leftTwips != null) {
          indentLeftPoints = leftTwips / _twipsPerPoint;
        }
        if (rightTwips != null) {
          indentRightPoints = rightTwips / _twipsPerPoint;
        }
        if (hangingTwips != null) {
          indentFirstLinePoints = -hangingTwips / _twipsPerPoint;
        } else if (firstLineTwips != null) {
          indentFirstLinePoints = firstLineTwips / _twipsPerPoint;
        }
    }
  }

  return _ParagraphPropertiesRaw(
    spacingBeforePoints: spacingBeforePoints,
    spacingAfterPoints: spacingAfterPoints,
    lineSpacingMultiple: lineSpacingMultiple,
    lineSpacingExactPoints: lineSpacingExactPoints,
    keepWithNext: keepWithNext,
    contextualSpacing: contextualSpacing,
    alignment: alignment,
    indentLeftPoints: indentLeftPoints,
    indentRightPoints: indentRightPoints,
    indentFirstLinePoints: indentFirstLinePoints,
  );
}

DocumentAlignment? _parseAlignment(String? value) {
  return switch (value) {
    'center' => DocumentAlignment.center,
    'right' || 'end' => DocumentAlignment.end,
    'both' || 'distribute' => DocumentAlignment.justify,
    'left' || 'start' => DocumentAlignment.start,
    _ => null,
  };
}

/// Fuentes del tema (`word/theme/themeN.xml`), a las que apunta `w:rFonts`
/// cuando usa `w:asciiTheme`/`w:hAnsiTheme` en vez de un nombre literal.
_ThemeFonts _parseThemeFonts(Map<String, ArchiveFile> archiveEntries) {
  final themePath = archiveEntries.keys.firstWhere(
    (path) => path.startsWith('word/theme/') && path.endsWith('.xml'),
    orElse: () => '',
  );
  if (themePath.isEmpty) {
    return const _ThemeFonts();
  }

  XmlElement root;
  try {
    root = XmlDocument.parse(
      _archiveEntryAsString(archiveEntries[themePath]!),
    ).rootElement;
  } catch (_) {
    return const _ThemeFonts();
  }

  String? majorLatin;
  String? minorLatin;
  for (final element in root.descendants.whereType<XmlElement>()) {
    final localName = element.name.local;
    if (localName != 'majorFont' && localName != 'minorFont') {
      continue;
    }
    final latin = _firstChildByLocalName(element, 'latin');
    final typeface = latin == null ? null : _attributeValue(latin, 'typeface');
    if (typeface == null || typeface.isEmpty) {
      continue;
    }
    if (localName == 'majorFont') {
      majorLatin ??= typeface;
    } else {
      minorLatin ??= typeface;
    }
  }

  return _ThemeFonts(majorLatin: majorLatin, minorLatin: minorLatin);
}

// Indexa `word/styles.xml`: docDefaults resuelto de una vez, y cada estilo
// SIN resolver su cadena w:basedOn todavía (eso lo hace `_StylesTable`, con
// memoización, la primera vez que se pide). Ausencia total de styles.xml (o
// de la entrada) -> tabla vacía, que resuelve siempre al docDefaults por
// defecto: mismo comportamiento que para documentos sin estilos.
_StylesTable _parseStylesTable(
  Map<String, ArchiveFile> archiveEntries,
  _ThemeFonts themeFonts,
) {
  final entry = archiveEntries['word/styles.xml'];
  if (entry == null) {
    return _StylesTable.empty();
  }

  XmlElement root;
  try {
    root = XmlDocument.parse(_archiveEntryAsString(entry)).rootElement;
  } catch (_) {
    return _StylesTable.empty();
  }

  var docDefaults = const _ResolvedParagraphStyle();
  final docDefaultsElement = _firstChildByLocalName(root, 'docDefaults');
  if (docDefaultsElement != null) {
    final rPrDefault = _firstChildByLocalName(docDefaultsElement, 'rPrDefault');
    final pPrDefault = _firstChildByLocalName(docDefaultsElement, 'pPrDefault');
    docDefaults = const _ResolvedParagraphStyle().mergeWith(
      runProperties: _parseRunProperties(
        rPrDefault == null ? null : _firstChildByLocalName(rPrDefault, 'rPr'),
        themeFonts: themeFonts,
      ),
      paragraphProperties: _parseParagraphProperties(
        pPrDefault == null ? null : _firstChildByLocalName(pPrDefault, 'pPr'),
      ),
    );
  }

  final paragraphStyles = <String, _RawStyle>{};
  final characterStyles = <String, _RawStyle>{};
  final tableStyles = <String, _RawTableStyle>{};

  for (final element in root.childElements) {
    if (element.name.local != 'style') {
      continue;
    }
    final styleId = _attributeValue(element, 'styleId');
    if (styleId == null) {
      continue;
    }

    final basedOnElement = _firstChildByLocalName(element, 'basedOn');
    final basedOn = basedOnElement == null
        ? null
        : _attributeValue(basedOnElement, 'val');
    final type = _attributeValue(element, 'type');

    if (type == 'table') {
      final tableProperties = _firstChildByLocalName(element, 'tblPr');
      tableStyles[styleId] = _RawTableStyle(
        basedOn: basedOn,
        borders: _parseTableBorders(
          tableProperties == null
              ? null
              : _firstChildByLocalName(tableProperties, 'tblBorders'),
        ),
      );
      continue;
    }

    final raw = _RawStyle(
      basedOn: basedOn,
      runProperties: _parseRunProperties(
        _firstChildByLocalName(element, 'rPr'),
        themeFonts: themeFonts,
      ),
      paragraphProperties: _parseParagraphProperties(
        _firstChildByLocalName(element, 'pPr'),
      ),
    );

    if (type == 'character') {
      characterStyles[styleId] = raw;
    } else if (type == 'paragraph' || type == null) {
      paragraphStyles[styleId] = raw;
    }
  }

  return _StylesTable(
    docDefaults: docDefaults,
    paragraphStyles: paragraphStyles,
    characterStyles: characterStyles,
    tableStyles: tableStyles,
  );
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

final class _ImageSize {
  const _ImageSize(this.width, this.height);

  final double width;
  final double height;
}

final class _TableBorders {
  const _TableBorders({this.widthPoints = 0, this.colorHex});

  final double widthPoints;
  final String? colorHex;
}

final class _ThemeFonts {
  const _ThemeFonts({this.majorLatin, this.minorLatin});

  final String? majorLatin;
  final String? minorLatin;
}

/// Estado compartido por el parseo de una parte (document.xml, headerN.xml,
/// footerN.xml): el ZIP completo, las relaciones de ESA parte, los estilos
/// del documento y el acumulador de omisiones.
final class _ParseContext {
  const _ParseContext({
    required this.archiveEntries,
    required this.relationships,
    required this.stylesTable,
    required this.omissions,
  });

  final Map<String, ArchiveFile> archiveEntries;
  final Map<String, String> relationships;
  final _StylesTable stylesTable;
  final Set<DocumentOmission> omissions;

  _ParseContext withRelationships(Map<String, String> relationships) {
    return _ParseContext(
      archiveEntries: archiveEntries,
      relationships: relationships,
      stylesTable: stylesTable,
      omissions: omissions,
    );
  }
}

// Propiedades resueltas de un run individual, ya con la cascada aplicada.
final class _RunStyle {
  const _RunStyle({
    required this.isBold,
    required this.isItalic,
    required this.isUnderlined,
    this.colorHex,
    this.fontSizePoints,
    this.fontFamily,
    this.isHidden = false,
  });

  final bool isBold;
  final bool isItalic;
  final bool isUnderlined;
  final String? colorHex;
  final double? fontSizePoints;
  final String? fontFamily;
  final bool isHidden;
}

final class _RunPropertiesRaw {
  const _RunPropertiesRaw({
    this.isBold,
    this.isItalic,
    this.isUnderlined,
    this.colorHex,
    this.fontSizePoints,
    this.fontFamily,
  });

  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderlined;
  final String? colorHex;
  final double? fontSizePoints;
  final String? fontFamily;
}

final class _ParagraphPropertiesRaw {
  const _ParagraphPropertiesRaw({
    this.spacingBeforePoints,
    this.spacingAfterPoints,
    this.lineSpacingMultiple,
    this.lineSpacingExactPoints,
    this.keepWithNext,
    this.contextualSpacing,
    this.alignment,
    this.indentLeftPoints,
    this.indentRightPoints,
    this.indentFirstLinePoints,
  });

  final double? spacingBeforePoints;
  final double? spacingAfterPoints;
  final double? lineSpacingMultiple;
  final double? lineSpacingExactPoints;
  final bool? keepWithNext;
  final bool? contextualSpacing;
  final DocumentAlignment? alignment;
  final double? indentLeftPoints;
  final double? indentRightPoints;
  final double? indentFirstLinePoints;
}

/// Estilo con nombre tal como aparece en styles.xml, SIN resolver su cadena
/// `w:basedOn`. null en un campo = ese estilo no lo define y hereda del padre.
final class _RawStyle {
  const _RawStyle({
    this.basedOn,
    this.runProperties = const _RunPropertiesRaw(),
    this.paragraphProperties = const _ParagraphPropertiesRaw(),
  });

  final String? basedOn;
  final _RunPropertiesRaw runProperties;
  final _ParagraphPropertiesRaw paragraphProperties;
}

final class _RawTableStyle {
  const _RawTableStyle({this.basedOn, this.borders = const _TableBorders()});

  final String? basedOn;
  final _TableBorders borders;
}

/// Estilo de párrafo YA resuelto (cascada docDefaults -> basedOn* -> estilo
/// específico -> formato directo). Todos los campos concretos: bool con
/// default false, spacing/sangrías con default 0, colorHex/fontSizePoints/
/// fontFamily/interlineado null cuando ningún nivel de la cascada los definió
/// (el renderer aplica entonces su propio default).
final class _ResolvedParagraphStyle {
  const _ResolvedParagraphStyle({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderlined = false,
    this.colorHex,
    this.fontSizePoints,
    this.fontFamily,
    this.spacingBeforePoints = 0,
    this.spacingAfterPoints = 0,
    this.lineSpacingMultiple,
    this.lineSpacingExactPoints,
    this.keepWithNext = false,
    this.contextualSpacing = false,
    this.alignment = DocumentAlignment.start,
    this.indentLeftPoints = 0,
    this.indentRightPoints = 0,
    this.indentFirstLinePoints = 0,
  });

  final bool isBold;
  final bool isItalic;
  final bool isUnderlined;
  final String? colorHex;
  final double? fontSizePoints;
  final String? fontFamily;
  final double spacingBeforePoints;
  final double spacingAfterPoints;
  final double? lineSpacingMultiple;
  final double? lineSpacingExactPoints;
  final bool keepWithNext;
  final bool contextualSpacing;
  final DocumentAlignment alignment;
  final double indentLeftPoints;
  final double indentRightPoints;
  final double indentFirstLinePoints;

  _ResolvedParagraphStyle mergeWith({
    required _RunPropertiesRaw runProperties,
    required _ParagraphPropertiesRaw paragraphProperties,
  }) {
    // `line` y `lineRule` son excluyentes entre sí en el mismo `w:spacing`:
    // declarar uno debe borrar el heredado del otro tipo.
    final declaresLineSpacing =
        paragraphProperties.lineSpacingMultiple != null ||
        paragraphProperties.lineSpacingExactPoints != null;

    return _ResolvedParagraphStyle(
      isBold: runProperties.isBold ?? isBold,
      isItalic: runProperties.isItalic ?? isItalic,
      isUnderlined: runProperties.isUnderlined ?? isUnderlined,
      colorHex: runProperties.colorHex ?? colorHex,
      fontSizePoints: runProperties.fontSizePoints ?? fontSizePoints,
      fontFamily: runProperties.fontFamily ?? fontFamily,
      spacingBeforePoints:
          paragraphProperties.spacingBeforePoints ?? spacingBeforePoints,
      spacingAfterPoints:
          paragraphProperties.spacingAfterPoints ?? spacingAfterPoints,
      lineSpacingMultiple: declaresLineSpacing
          ? paragraphProperties.lineSpacingMultiple
          : lineSpacingMultiple,
      lineSpacingExactPoints: declaresLineSpacing
          ? paragraphProperties.lineSpacingExactPoints
          : lineSpacingExactPoints,
      keepWithNext: paragraphProperties.keepWithNext ?? keepWithNext,
      contextualSpacing:
          paragraphProperties.contextualSpacing ?? contextualSpacing,
      alignment: paragraphProperties.alignment ?? alignment,
      indentLeftPoints:
          paragraphProperties.indentLeftPoints ?? indentLeftPoints,
      indentRightPoints:
          paragraphProperties.indentRightPoints ?? indentRightPoints,
      indentFirstLinePoints:
          paragraphProperties.indentFirstLinePoints ?? indentFirstLinePoints,
    );
  }
}

// Tabla de estilos de un documento: docDefaults ya resuelto + estilos con
// nombre sin resolver, resueltos bajo demanda y memoizados.
final class _StylesTable {
  _StylesTable({
    required this.docDefaults,
    required this.paragraphStyles,
    required this.characterStyles,
    required this.tableStyles,
  });

  _StylesTable.empty()
    : docDefaults = const _ResolvedParagraphStyle(),
      paragraphStyles = const <String, _RawStyle>{},
      characterStyles = const <String, _RawStyle>{},
      tableStyles = const <String, _RawTableStyle>{};

  final _ResolvedParagraphStyle docDefaults;
  final Map<String, _RawStyle> paragraphStyles;
  final Map<String, _RawStyle> characterStyles;
  final Map<String, _RawTableStyle> tableStyles;
  final Map<String, _ResolvedParagraphStyle> _paragraphCache =
      <String, _ResolvedParagraphStyle>{};
  final Map<String, _RunPropertiesRaw> _characterCache =
      <String, _RunPropertiesRaw>{};

  // pStyleId null -> usa "Normal" si existe (el comportamiento por defecto
  // de OOXML para un párrafo sin w:pStyle explícito), o docDefaults si ni
  // siquiera hay un estilo "Normal" definido.
  _ResolvedParagraphStyle resolve(String? pStyleId) {
    final effectiveId =
        pStyleId ?? (paragraphStyles.containsKey('Normal') ? 'Normal' : null);
    if (effectiveId == null) {
      return docDefaults;
    }

    final cached = _paragraphCache[effectiveId];
    if (cached != null) {
      return cached;
    }

    var resolved = docDefaults;
    for (final raw in _styleChain(paragraphStyles, effectiveId).reversed) {
      resolved = resolved.mergeWith(
        runProperties: raw.runProperties,
        paragraphProperties: raw.paragraphProperties,
      );
    }

    _paragraphCache[effectiveId] = resolved;
    return resolved;
  }

  _RunPropertiesRaw resolveCharacterStyle(String? rStyleId) {
    if (rStyleId == null) {
      return const _RunPropertiesRaw();
    }

    final cached = _characterCache[rStyleId];
    if (cached != null) {
      return cached;
    }

    var resolved = const _RunPropertiesRaw();
    for (final raw in _styleChain(characterStyles, rStyleId).reversed) {
      final properties = raw.runProperties;
      resolved = _RunPropertiesRaw(
        isBold: properties.isBold ?? resolved.isBold,
        isItalic: properties.isItalic ?? resolved.isItalic,
        isUnderlined: properties.isUnderlined ?? resolved.isUnderlined,
        colorHex: properties.colorHex ?? resolved.colorHex,
        fontSizePoints: properties.fontSizePoints ?? resolved.fontSizePoints,
        fontFamily: properties.fontFamily ?? resolved.fontFamily,
      );
    }

    _characterCache[rStyleId] = resolved;
    return resolved;
  }

  _TableBorders resolveTableBorders(String tableStyleId) {
    var currentId = tableStyleId;
    final visited = <String>{};
    while (visited.add(currentId)) {
      final raw = tableStyles[currentId];
      if (raw == null) {
        return const _TableBorders();
      }
      if (raw.borders.widthPoints > 0) {
        return raw.borders;
      }
      final basedOn = raw.basedOn;
      if (basedOn == null) {
        return const _TableBorders();
      }
      currentId = basedOn;
    }
    return const _TableBorders();
  }

  // Cadena w:basedOn del más específico al más lejano, con guardia anti-ciclo
  // y tope de profundidad: cadenas reales son 1-2 niveles, 5 es margen amplio
  // sin soportar herencia arbitrariamente larga.
  List<_RawStyle> _styleChain(Map<String, _RawStyle> styles, String styleId) {
    final chain = <_RawStyle>[];
    final visited = <String>{};
    var currentId = styleId;
    while (chain.length < 5 && visited.add(currentId)) {
      final raw = styles[currentId];
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
    return chain;
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
