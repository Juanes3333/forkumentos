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

  /// Renders a cell's [CellValue] the way the user saw it in Excel instead
  /// of the package's raw representation (e.g. an ISO timestamp with a
  /// trailing time-of-day for a date-only cell, or scientific notation for
  /// a plain decimal).
  ///
  /// ponytail: only dates and scientific notation are normalized. Excel's
  /// exact currency/thousands-separator rendering would require replaying
  /// `Data.cellStyle.numberFormat`, which is a formatting engine on its
  /// own — out of scope until a real report needs it.
  static String? formatCellValue(CellValue? cellValue) {
    return switch (cellValue) {
      null => null,
      DateCellValue(:final year, :final month, :final day) => _formatDate(
        year,
        month,
        day,
      ),
      DateTimeCellValue(
        :final year,
        :final month,
        :final day,
        :final hour,
        :final minute,
      ) =>
        '${_formatDate(year, month, day)} '
            '${hour.toString().padLeft(2, '0')}:'
            '${minute.toString().padLeft(2, '0')}',
      DoubleCellValue(:final value) => _formatDouble(value),
      _ => cellValue.toString(),
    };
  }

  static String _formatDate(int year, int month, int day) {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  static String _formatDouble(double value) {
    final raw = value.toString();
    if (!raw.contains('e') && !raw.contains('E')) {
      return raw;
    }
    // ponytail: fixed-point fallback for the rare double whose default
    // Dart toString() lands in scientific notation (very large/small
    // magnitudes). Trims trailing zeros so ordinary values stay tidy.
    final fixed = value.toStringAsFixed(10).replaceFirst(RegExp(r'0+$'), '');
    return fixed.endsWith('.') ? fixed.substring(0, fixed.length - 1) : fixed;
  }
}
