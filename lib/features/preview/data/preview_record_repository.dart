import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/data/xlsx_sheet_parser.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';

final _csvDecoder = Csv(autoDetect: false).decoder;

final previewRecordRepositoryProvider = Provider<PreviewRecordRepository>(
  (ref) => PreviewRecordRepository(),
);

/// Reads datasource rows for preview/export.
///
/// XLSX rows are cached per source path for the repository lifetime.
/// CSV export batches scan the file once in index order.
final class PreviewRecordRepository {
  PreviewRecordRepository();

  String? _xlsxCachePath;
  List<List<String?>>? _xlsxCacheRows;
  int _xlsxDecodeCount = 0;

  /// How many times the XLSX workbook was decoded (tests / diagnostics).
  @visibleForTesting
  int get xlsxDecodeCount => _xlsxDecodeCount;

  Future<List<String?>> readRecord({
    required Datasource datasource,
    required int rowIndex,
  }) async {
    if (rowIndex < 0 || rowIndex >= datasource.rowCount) {
      return List<String?>.filled(datasource.headers.length, null);
    }

    return switch (datasource.format) {
      DatasourceFormat.csv => _readCsvRecord(
        filePath: datasource.sourcePath,
        rowIndex: rowIndex,
        expectedLength: datasource.headers.length,
      ),
      DatasourceFormat.xlsx => _readXlsxRecord(
        filePath: datasource.sourcePath,
        rowIndex: rowIndex,
        expectedLength: datasource.headers.length,
      ),
    };
  }

  /// Resolves many row indexes in one pass (CSV) or from the XLSX cache.
  Future<Map<int, List<String?>>> readRecords({
    required Datasource datasource,
    required List<int> rowIndexes,
  }) async {
    final expectedLength = datasource.headers.length;
    final unique = <int>{
      for (final index in rowIndexes)
        if (index >= 0 && index < datasource.rowCount) index,
    };

    if (unique.isEmpty) {
      return <int, List<String?>>{
        for (final index in rowIndexes)
          index: List<String?>.filled(expectedLength, null),
      };
    }

    final resolved = switch (datasource.format) {
      DatasourceFormat.csv => await _readCsvRecords(
        filePath: datasource.sourcePath,
        rowIndexes: unique,
        expectedLength: expectedLength,
      ),
      DatasourceFormat.xlsx => await _readXlsxRecords(
        filePath: datasource.sourcePath,
        rowIndexes: unique,
        expectedLength: expectedLength,
      ),
    };

    return <int, List<String?>>{
      for (final index in rowIndexes)
        index: resolved[index] ?? List<String?>.filled(expectedLength, null),
    };
  }

  Future<List<String?>> _readXlsxRecord({
    required String filePath,
    required int rowIndex,
    required int expectedLength,
  }) async {
    final rows = await _xlsxRows(
      filePath: filePath,
      expectedLength: expectedLength,
    );
    if (rowIndex < 0 || rowIndex >= rows.length) {
      return List<String?>.filled(expectedLength, null);
    }
    return rows[rowIndex];
  }

  Future<Map<int, List<String?>>> _readXlsxRecords({
    required String filePath,
    required Set<int> rowIndexes,
    required int expectedLength,
  }) async {
    final rows = await _xlsxRows(
      filePath: filePath,
      expectedLength: expectedLength,
    );
    return <int, List<String?>>{
      for (final index in rowIndexes)
        index: index >= 0 && index < rows.length
            ? rows[index]
            : List<String?>.filled(expectedLength, null),
    };
  }

  Future<List<List<String?>>> _xlsxRows({
    required String filePath,
    required int expectedLength,
  }) async {
    if (_xlsxCachePath == filePath && _xlsxCacheRows != null) {
      return _xlsxCacheRows!;
    }

    final bytes = await File(filePath).readAsBytes();
    final rows = await compute<_XlsxTableRequest, List<List<String?>>>(
      _decodeXlsxTableInIsolate,
      _XlsxTableRequest(bytes: bytes, expectedLength: expectedLength),
    );
    _xlsxDecodeCount++;
    _xlsxCachePath = filePath;
    _xlsxCacheRows = rows;
    return rows;
  }
}

Future<List<String?>> _readCsvRecord({
  required String filePath,
  required int rowIndex,
  required int expectedLength,
}) async {
  final resolved = await _readCsvRecords(
    filePath: filePath,
    rowIndexes: <int>{rowIndex},
    expectedLength: expectedLength,
  );
  return resolved[rowIndex] ?? List<String?>.filled(expectedLength, null);
}

Future<Map<int, List<String?>>> _readCsvRecords({
  required String filePath,
  required Set<int> rowIndexes,
  required int expectedLength,
}) async {
  if (rowIndexes.isEmpty) {
    return const <int, List<String?>>{};
  }

  final needed = rowIndexes.toList()..sort();
  final rows = File(
    filePath,
  ).openRead().transform(utf8.decoder).transform<List<dynamic>>(_csvDecoder);

  final result = <int, List<String?>>{};
  var currentIndex = -1;
  var neededCursor = 0;

  await for (final List<dynamic> row in rows) {
    if (currentIndex == -1) {
      currentIndex = 0;
      continue;
    }

    while (neededCursor < needed.length &&
        needed[neededCursor] < currentIndex) {
      neededCursor++;
    }
    if (neededCursor >= needed.length) {
      break;
    }

    if (needed[neededCursor] == currentIndex) {
      result[currentIndex] = _normalizeCsvRow(row, expectedLength);
      neededCursor++;
      if (neededCursor >= needed.length) {
        break;
      }
    }
    currentIndex++;
  }

  return result;
}

List<String?> _normalizeCsvRow(List<dynamic> row, int expectedLength) {
  return List<String?>.generate(expectedLength, (index) {
    if (index >= row.length) {
      return null;
    }
    final value = row[index]?.toString() ?? '';
    return value.isEmpty ? null : value;
  }, growable: false);
}

List<List<String?>> _decodeXlsxTableInIsolate(_XlsxTableRequest request) {
  final bytes = XlsxSheetParser.coerceBytes(request.bytes);
  final workbook = XlsxSheetParser.decodeWorkbook(bytes);
  final sheet = XlsxSheetParser.firstSheetWithHeaders(workbook);
  final sheetRows = sheet.rows;
  if (sheetRows.length <= 1) {
    return const <List<String?>>[];
  }

  return List<List<String?>>.generate(sheetRows.length - 1, (dataIndex) {
    final row = sheetRows[dataIndex + 1];
    return List<String?>.generate(request.expectedLength, (index) {
      if (index >= row.length) {
        return null;
      }
      final value = row[index]?.value?.toString() ?? '';
      return value.isEmpty ? null : value;
    }, growable: false);
  }, growable: false);
}

final class _XlsxTableRequest {
  const _XlsxTableRequest({required this.bytes, required this.expectedLength});

  final List<int> bytes;
  final int expectedLength;
}
