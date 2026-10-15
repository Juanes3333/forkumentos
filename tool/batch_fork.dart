// Batch-creates `.fork` projects from a folder of matching `.docx`/`.xlsx`
// pairs (same base name, different extension), with auto-mapping already
// applied.
//
// Reuses the app's own pure-Dart domain code (buildAutoMapping,
// findExactTextOccurrences, mappingAssignmentsToJson) directly — none of it
// depends on Flutter — so the mapping produced here is identical to what the
// app's "Auto-mapear" button would produce. The only piece reimplemented
// here is a minimal `word/document.xml` reader that builds a paragraph/table
// skeleton good enough for text search: it does not split paragraphs on
// internal page breaks the way the full DOCX ingestion parser does, so a
// `<w:p>`/`<w:tbl>` in document order always maps 1:1 to one root block here.
//
// Usage:
//   dart run tool/batch_fork.dart "C:\ruta\a\la\carpeta" ["C:\ruta\de\salida"]
//
// Only scans the top level of the input folder (not subfolders). Output
// defaults to the input folder when the second argument is omitted.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:forkumentos/features/datasource/data/xlsx_sheet_parser.dart';
import 'package:forkumentos/features/mapping/data/mapping_json.dart';
import 'package:forkumentos/features/mapping/domain/auto_mapping.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

const _manifestFileName = 'manifest.json';
const _projectFileName = 'project.json';
const _mappingsFileName = 'mappings.json';
const _templateDirName = 'template';
const _datasourceDirName = 'datasource';
const _manifestVersion = 1;

const _uuid = Uuid();

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/batch_fork.dart <carpeta_de_entrada> '
      '[carpeta_de_salida]',
    );
    exitCode = 64;
    return;
  }

  final inputDir = args[0];
  final outputDir = args.length > 1 ? args[1] : inputDir;

  if (!Directory(inputDir).existsSync()) {
    stderr.writeln('La carpeta de entrada no existe: $inputDir');
    exitCode = 66;
    return;
  }
  await Directory(outputDir).create(recursive: true);

  final docxFiles = <File>[];
  final xlsxByBaseName = <String, File>{};
  for (final entity in Directory(inputDir).listSync()) {
    if (entity is! File) {
      continue;
    }
    switch (p.extension(entity.path).toLowerCase()) {
      case '.docx':
        docxFiles.add(entity);
      case '.xlsx':
        xlsxByBaseName[p.basenameWithoutExtension(entity.path).toLowerCase()] =
            entity;
    }
  }

  final created = <String>[];
  final failed = <String>[];

  for (final docxFile in docxFiles) {
    final baseName = p.basenameWithoutExtension(docxFile.path);
    final xlsxFile = xlsxByBaseName[baseName.toLowerCase()];
    if (xlsxFile == null) {
      stdout.writeln(
        'Advertencia: no se encontró un .xlsx para '
        '"${p.basename(docxFile.path)}". Se omite.',
      );
      continue;
    }

    final projectName = _cleanProjectName(baseName);
    try {
      final forkBytes = await _buildFork(
        projectName: projectName,
        docxFile: docxFile,
        xlsxFile: xlsxFile,
      );
      final outPath = p.join(outputDir, '$projectName.fork');
      await File(outPath).writeAsBytes(forkBytes, flush: true);
      created.add(outPath);
      stdout.writeln('Creado: $outPath');
    } on Object catch (error) {
      failed.add('$baseName: $error');
      stdout.writeln('Error procesando "$baseName": $error');
    }
  }

  stdout
    ..writeln()
    ..writeln(
      'Resumen: ${created.length} .fork creados, '
      '${failed.length} pares fallidos.',
    );
  if (failed.isNotEmpty) {
    stdout.writeln('Pares no procesados:');
    for (final failure in failed) {
      stdout.writeln('  - $failure');
    }
  }
}

/// Strips the ` PARA FORKUMENTOS` / ` FORKUMENTOS PARA` / ` FORKUMENTOS`
/// naming-convention suffixes (case-insensitive) that template authors add.
String _cleanProjectName(String baseName) {
  const variants = <String>[
    ' PARA FORKUMENTOS',
    ' FORKUMENTOS PARA',
    ' FORKUMENTOS',
  ];
  var cleaned = baseName;
  for (final variant in variants) {
    cleaned = cleaned.replaceAll(
      RegExp(RegExp.escape(variant), caseSensitive: false),
      '',
    );
  }
  return cleaned.trim();
}

Future<Uint8List> _buildFork({
  required String projectName,
  required File docxFile,
  required File xlsxFile,
}) async {
  final docxBytes = await docxFile.readAsBytes();
  final xlsxBytes = await xlsxFile.readAsBytes();

  final document = _documentFromDocxBytes(docxBytes);
  final (headers, firstRow) = _readFirstDataRow(xlsxBytes);

  final autoMapping = buildAutoMapping(
    document: document,
    headers: headers,
    firstRow: firstRow,
    existingAssignments: const [],
    generateId: _uuid.v4,
  );
  final assignments = [
    for (final assignment in autoMapping.assignments)
      _withListFieldHeuristic(assignment, document),
  ];

  final now = DateTime.now().toUtc();
  final archive = Archive()
    ..addFile(
      _utf8File(
        _manifestFileName,
        jsonEncode(<String, dynamic>{'version': _manifestVersion}),
      ),
    )
    ..addFile(
      _utf8File(
        _projectFileName,
        jsonEncode(<String, dynamic>{
          'id': _uuid.v4(),
          'name': projectName,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        }),
      ),
    )
    ..addFile(
      _utf8File(
        _mappingsFileName,
        jsonEncode(mappingAssignmentsToJson(assignments)),
      ),
    )
    ..addFile(
      ArchiveFile(
        '$_templateDirName/${p.basename(docxFile.path)}',
        docxBytes.length,
        docxBytes,
      ),
    )
    ..addFile(
      ArchiveFile(
        '$_datasourceDirName/${p.basename(xlsxFile.path)}',
        xlsxBytes.length,
        xlsxBytes,
      ),
    );

  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('No se pudo codificar el archivo .fork.');
  }
  return Uint8List.fromList(encoded);
}

ArchiveFile _utf8File(String name, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes);
}

/// Builds a minimal [Document] (single fake page holding every root block)
/// good enough for [buildAutoMapping]'s text search: `rootBlockIndex` only
/// needs to count `<w:p>`/`<w:tbl>` in document order, never which page they
/// land on (see `document_text_path.dart`'s doc comment).
Document _documentFromDocxBytes(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final documentXmlFile = archive.files.firstWhere(
    (file) => file.name.toLowerCase() == 'word/document.xml',
    orElse: () => throw const FormatException(
      'El DOCX no contiene word/document.xml.',
    ),
  );
  final xmlContent = utf8.decode(documentXmlFile.content as List<int>);
  final body = XmlDocument.parse(
    xmlContent,
  ).rootElement.childElements.firstWhere(
    (element) => element.name.local == 'body',
    orElse: () =>
        throw const FormatException('El DOCX no contiene <w:body>.'),
  );

  final blocks = <DocumentBlock>[
    for (final child in body.childElements)
      if (child.name.local == 'p')
        DocumentBlock.paragraph(_paragraphFromElement(child))
      else if (child.name.local == 'tbl')
        DocumentBlock.table(_tableFromElement(child)),
  ];

  return Document(
    pages: <DocumentPage>[
      DocumentPage(
        number: 1,
        widthPoints: 612,
        heightPoints: 792,
        margins: const DocumentMargins(
          topPoints: 72,
          rightPoints: 72,
          bottomPoints: 72,
          leftPoints: 72,
        ),
        blocks: blocks,
      ),
    ],
    omissions: const <DocumentOmission>{},
  );
}

DocumentParagraph _paragraphFromElement(XmlElement paragraphElement) {
  final buffer = StringBuffer();
  for (final node in paragraphElement.descendants) {
    if (node is XmlElement && node.name.local == 't') {
      buffer.write(node.innerText);
    }
  }
  final numbering = _paragraphNumbering(paragraphElement);
  return DocumentParagraph(
    runs: <DocumentRun>[
      DocumentRun(
        text: buffer.toString(),
        isBold: false,
        isItalic: false,
        isUnderlined: false,
      ),
    ],
    numberingId: numbering.numId,
    numberingLevel: numbering.ilvl,
  );
}

/// Same shallow `<w:pPr><w:numPr>` read as
/// `docx_document_repository.dart`'s `_paragraphNumbering`: direct formatting
/// only, no `w:pStyle` cascade.
({int? numId, int? ilvl}) _paragraphNumbering(XmlElement paragraph) {
  final pPr = paragraph.childElements
      .where((e) => e.name.local == 'pPr')
      .firstOrNull;
  final numPr = pPr?.childElements
      .where((e) => e.name.local == 'numPr')
      .firstOrNull;
  if (numPr == null) {
    return (numId: null, ilvl: null);
  }
  int? valueOf(String localName) {
    final element = numPr.childElements
        .where((e) => e.name.local == localName)
        .firstOrNull;
    final value = element?.getAttribute('val');
    return value == null ? null : int.tryParse(value);
  }

  return (numId: valueOf('numId'), ilvl: valueOf('ilvl'));
}

/// Marks a root-level paragraph assignment as a list field when it targets a
/// paragraph with `numberingId != null`. Optional heuristic (task.md Paso 8):
/// the user can still toggle it manually in the app afterwards.
FieldAssignment _withListFieldHeuristic(
  FieldAssignment assignment,
  Document document,
) {
  if (assignment.path.region != DocumentTextRegion.body ||
      assignment.path.steps.length != 1) {
    return assignment;
  }
  final step = assignment.path.steps.single;
  if (step is! RootDocumentBlockStep) {
    return assignment;
  }
  final blocks = document.pages.single.blocks;
  if (step.blockIndex < 0 || step.blockIndex >= blocks.length) {
    return assignment;
  }
  final block = blocks[step.blockIndex];
  if (block is! DocumentParagraphBlock ||
      block.paragraph.numberingId == null) {
    return assignment;
  }
  return assignment.copyWith(isListField: true);
}

/// Nested tables inside a cell are skipped — same simplification as the rest
/// of this script's DOCX reader.
DocumentTable _tableFromElement(XmlElement tableElement) {
  final rows = <DocumentTableRow>[];
  for (final rowElement in tableElement.childElements) {
    if (rowElement.name.local != 'tr') {
      continue;
    }
    final cells = <DocumentTableCell>[];
    for (final cellElement in rowElement.childElements) {
      if (cellElement.name.local != 'tc') {
        continue;
      }
      cells.add(
        DocumentTableCell(
          blocks: <DocumentBlock>[
            for (final child in cellElement.childElements)
              if (child.name.local == 'p')
                DocumentBlock.paragraph(_paragraphFromElement(child)),
          ],
        ),
      );
    }
    rows.add(DocumentTableRow(cells: cells));
  }
  return DocumentTable(rows: rows);
}

/// Reads headers (row 1) and the first data row (row 2) from the XLSX,
/// mirroring the trailing-empty-trim / positional-naming rules
/// `XlsxDatasourceRepository` applies when the app imports a datasource.
(List<String>, List<String?>) _readFirstDataRow(Uint8List xlsxBytes) {
  final workbook = XlsxSheetParser.decodeWorkbook(xlsxBytes);
  final sheet = XlsxSheetParser.firstSheetWithHeaders(workbook);
  final rows = sheet.rows;

  final headers = rows.first
      .map((cell) => XlsxSheetParser.formatCellValue(cell?.value) ?? '')
      .toList();
  while (headers.isNotEmpty && headers.last.trim().isEmpty) {
    headers.removeLast();
  }
  for (var index = 0; index < headers.length; index++) {
    if (headers[index].trim().isEmpty) {
      headers[index] = 'Columna ${index + 1}';
    }
  }

  final dataRows = rows.skip(1).toList();
  if (dataRows.isEmpty) {
    return (headers, List<String?>.filled(headers.length, null));
  }

  final firstDataRow = dataRows.first;
  final row = List<String?>.generate(headers.length, (index) {
    if (index >= firstDataRow.length) {
      return null;
    }
    final value = XlsxSheetParser.formatCellValue(firstDataRow[index]?.value);
    return (value == null || value.isEmpty) ? null : value;
  });
  return (headers, row);
}
