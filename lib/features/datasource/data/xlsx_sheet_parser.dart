import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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
    Object? firstError;
    try {
      return Excel.decodeBytes(bytes);
    } catch (error) {
      firstError = error;
    }

    // El paquete `excel` (4.0.6) lanza al ver un <numFmt> con numFmtId < 164
    // (el rango reservado para formatos integrados). Excel/LibreOffice sí los
    // redefinen ahí para monedas y formatos regionales, dejando el .xlsx
    // "válido pero ilegible". Reintentamos tras reubicar esos ids al rango
    // personalizado; el formato visual no nos importa (solo leemos valores).
    final sanitized = _sanitizeBuiltinNumberFormats(bytes);
    if (sanitized != null) {
      try {
        return Excel.decodeBytes(sanitized);
      } catch (_) {
        // fall through
      }
    }

    if (firstError.toString().contains('numFmtId')) {
      throw const FormatException(
        'El archivo XLSX usa un formato de número o moneda que no se pudo '
        'leer. Abre el archivo en Excel, cambia esa columna a formato '
        '"General" o "Texto", y guarda una copia.',
      );
    }
    throw const FormatException('El archivo XLSX tiene un formato inválido.');
  }

  /// Rewrites `xl/styles.xml` so any `<numFmt numFmtId="N">` with `N < 164`
  /// (and every `cellXfs` reference to it) moves into the custom range.
  /// Returns `null` when there is nothing to fix or the archive can't be
  /// rewritten, so the caller keeps the original bytes.
  static List<int>? _sanitizeBuiltinNumberFormats(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return null;
    }

    ArchiveFile? styles;
    for (final file in archive.files) {
      if (file.name.toLowerCase() == 'xl/styles.xml') {
        styles = file;
        break;
      }
    }
    final content = styles?.content;
    if (styles == null || content is! List<int>) {
      return null;
    }

    final xml = utf8.decode(content, allowMalformed: true);
    final rewritten = _relocateBuiltinNumFmtIds(xml);
    if (rewritten == null) {
      return null;
    }

    final output = Archive();
    for (final file in archive.files) {
      // Fresh ArchiveFile with already-decompressed bytes: re-adding the
      // decoded entries as-is confuses ZipEncoder about their compression
      // state (same reason docx_zip_exporter rebuilds every entry).
      final data = identical(file, styles)
          ? utf8.encode(rewritten)
          : (file.content as List<int>);
      output.addFile(ArchiveFile(file.name, data.length, data));
    }

    try {
      return ZipEncoder().encode(output);
    } catch (_) {
      return null;
    }
  }

  static final RegExp _numFmtIdAttr = RegExp(r'numFmtId="(\d+)"');
  static final RegExp _numFmtElementId = RegExp(
    r'<numFmt\b[^>]*?\bnumFmtId="(\d+)"',
  );

  static String? _relocateBuiltinNumFmtIds(String stylesXml) {
    final offending = <int>{};
    for (final match in _numFmtElementId.allMatches(stylesXml)) {
      final id = int.parse(match.group(1)!);
      if (id < 164) {
        offending.add(id);
      }
    }
    if (offending.isEmpty) {
      return null;
    }

    var maxId = 163;
    for (final match in _numFmtIdAttr.allMatches(stylesXml)) {
      final id = int.parse(match.group(1)!);
      if (id > maxId) {
        maxId = id;
      }
    }

    var nextId = maxId + 1;
    final remap = <int, int>{for (final id in offending) id: nextId++};

    // New ids are all > every existing id, so a single pass per old id can't
    // collide with another mapping.
    return stylesXml.replaceAllMapped(_numFmtIdAttr, (match) {
      final id = int.parse(match.group(1)!);
      final mapped = remap[id];
      return mapped == null ? match.group(0)! : 'numFmtId="$mapped"';
    });
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
  /// When [numberFormat] is the cell's `cellStyle.numberFormat`, currency /
  /// thousands / percent formats are replayed with es-CO conventions (`.`
  /// miles, `,` decimales) so `18414383` in una columna moneda sale como
  /// `$18.414.383`, igual que en Excel. Other numeric formats ("General",
  /// "0.00", …) keep the raw value.
  static String? formatCellValue(
    CellValue? cellValue, {
    NumFormat? numberFormat,
  }) {
    if (cellValue == null) {
      return null;
    }
    try {
      if (numberFormat != null) {
        final raw = switch (cellValue) {
          IntCellValue(:final value) => value as num,
          DoubleCellValue(:final value) => value as num,
          _ => null,
        };
        if (raw != null) {
          final formatted = _applyNumberFormat(raw, numberFormat.formatCode);
          if (formatted != null) {
            return formatted;
          }
        }
      }
      return switch (cellValue) {
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
    } catch (_) {
      // Un tipo de celda inesperado o un toString() que lanza no debe tumbar
      // la importación: mejor una celda vacía que un archivo irrecuperable.
      try {
        return cellValue.toString();
      } catch (_) {
        return null;
      }
    }
  }

  /// Devuelve `true` si todas las celdas de [row] están vacías (null, cadena
  /// vacía, o solo espacios en blanco). Usado para recortar filas fantasma
  /// que Excel conserva por formato (bordes, relleno) sin datos reales.
  static bool isEmptyRow(List<Data?> row) {
    return row.every((cell) {
      if (cell == null) return true;
      final value = formatCellValue(cell.value);
      return value == null || value.trim().isEmpty;
    });
  }

  static String _formatDate(int year, int month, int day) {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  /// Replays an Excel number [formatCode] onto [rawValue] with es-CO
  /// conventions. Returns `null` for plain formats ("General", "0", "0.00")
  /// so the caller keeps the raw value untouched.
  static String? _applyNumberFormat(num rawValue, String formatCode) {
    // The positive branch is the first `;`-separated section.
    final section = formatCode.split(';').first;

    final hasCurrency = RegExp(r'[$€£¤]').hasMatch(section);
    final hasGrouping = section.contains(',');
    final isPercent = section.contains('%');
    if (!hasCurrency && !hasGrouping && !isPercent) {
      return null;
    }

    var value = rawValue;
    if (isPercent) {
      value *= 100;
    }

    final decimals = _decimalPlacesInFormat(section);
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(decimals);
    final dotIndex = fixed.indexOf('.');
    final integerDigits = dotIndex == -1 ? fixed : fixed.substring(0, dotIndex);
    final fraction = dotIndex == -1 ? '' : fixed.substring(dotIndex + 1);

    final integerPart = hasGrouping
        ? _groupThousands(integerDigits)
        : integerDigits;
    var out = fraction.isEmpty ? integerPart : '$integerPart,$fraction';

    if (hasCurrency) {
      final symbol = section.contains('€')
          ? '€'
          : section.contains('£')
          ? '£'
          : r'$';
      out = '$symbol$out';
    }
    if (isPercent) {
      out = '$out%';
    }
    return negative ? '-$out' : out;
  }

  static int _decimalPlacesInFormat(String section) {
    final dotIndex = section.indexOf('.');
    if (dotIndex == -1) {
      return 0;
    }
    var count = 0;
    for (var i = dotIndex + 1; i < section.length; i++) {
      final char = section[i];
      if (char == '0' || char == '#') {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  static String _groupThousands(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
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
