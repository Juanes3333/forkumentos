import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:forkumentos/features/datasource/data/xlsx_sheet_parser.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/domain/datasource_repository.dart';
import 'package:path/path.dart' as p;

final class XlsxDatasourceRepository implements DatasourceRepository {
  const XlsxDatasourceRepository();

  @override
  Future<Datasource> load(String filePath) async {
    final normalizedExtension = p.extension(filePath).toLowerCase();
    if (normalizedExtension != '.xlsx') {
      throw const FormatException('Selecciona un archivo con extensión .xlsx.');
    }

    final bytes = await File(filePath).readAsBytes();
    // ponytail: el paquete `excel` decodifica el workbook completo en
    // memoria (no ofrece una API de lectura incremental). El parseo se
    // delega a un isolate vía compute() para no bloquear la UI; el techo es
    // memoria proporcional al tamaño del XLSX. Si esto genera presión de
    // memoria con archivos reales, la ruta de mejora es un lector XLSX
    // streaming/SAX.
    final parsed = await compute<Map<String, Object?>, Map<String, Object?>>(
      _parseXlsxContent,
      <String, Object?>{'bytes': bytes},
    );

    return Datasource(
      sourcePath: filePath,
      fileName: p.basename(filePath),
      fileSizeBytes: bytes.lengthInBytes,
      importedAt: DateTime.now().toUtc(),
      format: DatasourceFormat.xlsx,
      headers: (parsed['headers']! as List<Object?>).cast<String>(),
      previewRow: (parsed['previewRow']! as List<Object?>).cast<String?>(),
      rowCount: parsed['rowCount']! as int,
      emptyColumnIndexes: (parsed['emptyColumnIndexes']! as List<Object?>)
          .cast<int>(),
    );
  }
}

Map<String, Object?> _parseXlsxContent(Map<String, Object?> payload) {
  final bytes = XlsxSheetParser.coerceBytes(payload['bytes']);
  final workbook = XlsxSheetParser.decodeWorkbook(bytes);
  final sheet = XlsxSheetParser.firstSheetWithHeaders(workbook);
  final rows = sheet.rows;

  final headerRow = rows.first;
  final headers = headerRow.map(_normalizeHeaderCell).toList(growable: false);
  if (headers.every((String header) => header.isEmpty)) {
    throw const FormatException(
      'El archivo XLSX no contiene una fila de encabezados válida.',
    );
  }

  final duplicateHeaders = _findDuplicateHeaders(headers);
  if (duplicateHeaders.isNotEmpty) {
    throw FormatException(
      'El archivo contiene encabezados duplicados: '
      '${duplicateHeaders.join(', ')}.',
    );
  }

  final dataRows = rows.skip(1).toList(growable: false);
  final previewRow = dataRows.isEmpty
      ? List<String?>.filled(headers.length, null)
      : _toPreviewRow(row: dataRows.first, expectedLength: headers.length);
  final emptyColumnIndexes = _detectEmptyColumns(
    rows: dataRows,
    expectedLength: headers.length,
  );

  return <String, Object?>{
    'headers': headers,
    'previewRow': previewRow,
    'rowCount': dataRows.length,
    'emptyColumnIndexes': emptyColumnIndexes,
  };
}

String _normalizeHeaderCell(Data? cell) {
  final rawValue = cell?.value;
  if (rawValue == null) {
    return '';
  }
  return rawValue.toString();
}

List<String> _findDuplicateHeaders(List<String> headers) {
  final counts = <String, int>{};
  for (final header in headers) {
    counts.update(header, (int value) => value + 1, ifAbsent: () => 1);
  }

  return counts.entries
      .where((MapEntry<String, int> entry) => entry.value > 1)
      .map((MapEntry<String, int> entry) {
        if (entry.key.isEmpty) {
          return '(vacío)';
        }
        return entry.key;
      })
      .toList(growable: false);
}

List<String?> _toPreviewRow({
  required List<Data?> row,
  required int expectedLength,
}) {
  return List<String?>.generate(expectedLength, (int index) {
    if (index >= row.length) {
      return null;
    }
    return _normalizeDataCell(row[index]);
  }, growable: false);
}

List<int> _detectEmptyColumns({
  required List<List<Data?>> rows,
  required int expectedLength,
}) {
  final isColumnEmpty = List<bool>.filled(expectedLength, true);
  for (final row in rows) {
    for (var index = 0; index < expectedLength; index++) {
      if (index >= row.length) {
        continue;
      }

      if (_normalizeDataCell(row[index]) != null) {
        isColumnEmpty[index] = false;
      }
    }
  }

  final emptyColumnIndexes = <int>[];
  for (var index = 0; index < isColumnEmpty.length; index++) {
    if (isColumnEmpty[index]) {
      emptyColumnIndexes.add(index);
    }
  }
  return emptyColumnIndexes;
}

String? _normalizeDataCell(Data? data) {
  final value = data?.value;
  if (value == null) {
    return null;
  }

  final normalized = value.toString();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}
