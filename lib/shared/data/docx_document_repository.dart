import 'dart:convert';
import 'dart:io';

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

  final documentXml = _archiveEntryAsString(
    archiveEntries['word/document.xml']!,
  );
  final document = _parseDocumentXml(documentXml);
  final body = _findBody(document);
  final sectionProperties = _findSectionProperties(body);
  final sectionMetrics = _parseSectionMetrics(sectionProperties);
  final pages = _extractPages(body, omissions);

  final headerSegments = _resolveSectionReferenceBlocks(
    sectionProperties,
    archiveEntries,
    omissions,
    referenceLocalName: 'headerReference',
  );
  final footerSegments = _resolveSectionReferenceBlocks(
    sectionProperties,
    archiveEntries,
    omissions,
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
  );
}

double _asDouble(Object? value, double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

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
  Set<DocumentOmission> omissions, {
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

  return _parseContainerBlocks(parsed.rootElement, omissions);
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

// ponytail: la paginación se basa únicamente en marcadores explícitos
// (`w:br type="page"` / `w:lastRenderedPageBreak` / `w:pageBreakBefore`)
// presentes en el XML. No se reproduce el reflow automático de Word (que
// depende de métricas de fuente y layout reales). Un documento sin
// marcadores explícitos se muestra como una sola página, cuyo alto visual
// puede exceder el tamaño nominal de página si el contenido no cabe. El
// techo: fidelidad de paginación automática requeriría un motor tipográfico
// OOXML completo, fuera de alcance de este sprint.
List<_SerializedPage> _extractPages(
  XmlElement body,
  Set<DocumentOmission> omissions,
) {
  final pages = <_SerializedPage>[];
  var currentPageBlocks = <_SerializedBlock>[];

  for (final segment in _parseContainerBlocks(
    body,
    omissions,
    respectPageBreakBefore: true,
  )) {
    currentPageBlocks = <_SerializedBlock>[
      ...currentPageBlocks,
      <String, Object?>{...segment.block},
    ];

    if (segment.endsWithPageBreak) {
      pages.add(currentPageBlocks);
      currentPageBlocks = <_SerializedBlock>[];
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

List<_SerializedBlockSegment> _parseContainerBlocks(
  XmlElement container,
  Set<DocumentOmission> omissions, {
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

      final chunks = _splitParagraphByPageBreak(child, omissions);
      for (final chunk in chunks) {
        segments.add(
          _SerializedBlockSegment(
            block: <String, Object?>{
              'kind': 'paragraph',
              'runs': <Object?>[
                for (final run in chunk.runs) <String, Object?>{...run},
              ],
            },
            endsWithPageBreak: chunk.endsWithPageBreak,
          ),
        );
      }
      continue;
    }

    if (localName == 'tbl') {
      segments.add(
        _SerializedBlockSegment(
          block: _serializeTable(child, omissions),
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

      final nestedSegments = _parseContainerBlocks(cellElement, omissions);
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

List<_ParagraphChunk> _splitParagraphByPageBreak(
  XmlElement paragraph,
  Set<DocumentOmission> omissions,
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
          'isBold': runStyle.isBold,
          'isItalic': runStyle.isItalic,
          'isUnderlined': runStyle.isUnderlined,
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

_RunStyle _resolveRunStyle(XmlElement run) {
  XmlElement? runProperties;
  for (final child in run.childElements) {
    if (child.name.local == 'rPr') {
      runProperties = child;
      break;
    }
  }
  if (runProperties == null) {
    return const _RunStyle();
  }

  XmlElement? boldProperty;
  XmlElement? italicProperty;
  XmlElement? underlineProperty;
  var hasVanish = false;

  for (final property in runProperties.childElements) {
    final localName = property.name.local;
    if (localName == 'b') {
      boldProperty = property;
    } else if (localName == 'i') {
      italicProperty = property;
    } else if (localName == 'u') {
      underlineProperty = property;
    } else if (localName == 'vanish') {
      hasVanish = true;
    }
  }

  return _RunStyle(
    isBold: _isEnabledProperty(boldProperty),
    isItalic: _isEnabledProperty(italicProperty),
    isUnderlined: _isUnderlineEnabled(underlineProperty),
    isHidden: hasVanish,
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

final class _RunStyle {
  const _RunStyle({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderlined = false,
    this.isHidden = false,
  });

  final bool isBold;
  final bool isItalic;
  final bool isUnderlined;
  final bool isHidden;
}

final class _ParagraphChunk {
  const _ParagraphChunk({required this.runs, required this.endsWithPageBreak});

  final _SerializedParagraph runs;
  final bool endsWithPageBreak;
}

final class _SerializedBlockSegment {
  const _SerializedBlockSegment({
    required this.block,
    required this.endsWithPageBreak,
  });

  final _SerializedBlock block;
  final bool endsWithPageBreak;
}
