import 'dart:typed_data';

import 'package:excel/excel.dart';

/// Shared XLSX decode helpers used by datasource load and preview rows.
final class XlsxSheetParser {
  const XlsxSheetParser._();

  /// Accepts [Uint8List] or plain [List<int>] (compute may retype bytes).
  static List<int> coerceBytes(Object? bytes) {
    if (bytes is Uint8List) {
      return bytes;
    }
    if (bytes is List<int>) {
      return bytes;
    }
    throw const FormatException('El archivo XLSX tiene un formato inválido.');
  }

  static Excel decodeWorkbook(List<int> bytes) {
    try {
      return Excel.decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('El archivo XLSX tiene un formato inválido.');
    }
  }

  /// First sheet whose header row has at least one non-empty cell.
  static Sheet firstSheetWithHeaders(Excel workbook) {
    if (workbook.tables.isEmpty) {
      throw const FormatException(
        'El archivo XLSX está vacío o no contiene hojas válidas.',
      );
    }

    for (final sheet in workbook.tables.values) {
      if (_hasNonEmptyHeaderRow(sheet)) {
        return sheet;
      }
    }

    throw const FormatException(
      'El archivo XLSX no contiene una fila de encabezados válida.',
    );
  }

  static bool _hasNonEmptyHeaderRow(Sheet sheet) {
    if (sheet.rows.isEmpty) {
      return false;
    }
    final headerRow = sheet.rows.first;
    if (headerRow.isEmpty) {
      return false;
    }
    return headerRow.any((cell) {
      final value = cell?.value;
      if (value == null) {
        return false;
      }
      return value.toString().trim().isNotEmpty;
    });
  }
}
