import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';

final _csvDecoder = Csv(autoDetect: false).decoder;

final previewRecordRepositoryProvider = Provider<PreviewRecordRepository>(
  (ref) => const PreviewRecordRepository(),
);

final class PreviewRecordRepository {
  const PreviewRecordRepository();

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
}

Future<List<String?>> _readCsvRecord({
  required String filePath,
  required int rowIndex,
  required int expectedLength,
}) async {
  final rows = File(
    filePath,
  ).openRead().transform(utf8.decoder).transform<List<dynamic>>(_csvDecoder);

  var currentIndex = -1;
  await for (final List<dynamic> row in rows) {
    if (currentIndex == -1) {
      currentIndex = 0;
      continue;
    }

    if (currentIndex == rowIndex) {
      return _normalizeCsvRow(row, expectedLength);
    }
    currentIndex++;
  }

  return List<String?>.filled(expectedLength, null);
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

Future<List<String?>> _readXlsxRecord({
  required String filePath,
  required int rowIndex,
  required int expectedLength,
}) async {
  final bytes = await File(filePath).readAsBytes();
  return compute<_XlsxPreviewRequest, List<String?>>(
    _readXlsxRecordInIsolate,
    _XlsxPreviewRequest(
      bytes: bytes,
      rowIndex: rowIndex,
      expectedLength: expectedLength,
    ),
  );
}

List<String?> _readXlsxRecordInIsolate(_XlsxPreviewRequest request) {
  final workbook = Excel.decodeBytes(request.bytes);
  if (workbook.tables.isEmpty) {
    return List<String?>.filled(request.expectedLength, null);
  }

  final rows = workbook.tables.values.first.rows;
  final dataIndex = request.rowIndex + 1;
  if (dataIndex < 0 || dataIndex >= rows.length) {
    return List<String?>.filled(request.expectedLength, null);
  }

  final row = rows[dataIndex];
  return List<String?>.generate(request.expectedLength, (index) {
    if (index >= row.length) {
      return null;
    }
    final value = row[index]?.value?.toString() ?? '';
    return value.isEmpty ? null : value;
  }, growable: false);
}

final class _XlsxPreviewRequest {
  const _XlsxPreviewRequest({
    required this.bytes,
    required this.rowIndex,
    required this.expectedLength,
  });

  final List<int> bytes;
  final int rowIndex;
  final int expectedLength;
}
