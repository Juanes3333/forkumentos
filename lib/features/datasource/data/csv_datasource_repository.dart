import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/domain/datasource_repository.dart';
import 'package:path/path.dart' as p;

final _csvDecoder = Csv(autoDetect: false).decoder;

const _invalidCsvMessage = 'El archivo CSV tiene un formato inválido.';
const _emptyFileMessage =
    'El archivo CSV está vacío. '
    'Agrega una fila de encabezados e inténtalo nuevamente.';
const _missingHeaderMessage =
    'El archivo CSV no contiene una fila de encabezados válida.';

final class CsvDatasourceRepository implements DatasourceRepository {
  const CsvDatasourceRepository();

  @override
  Future<Datasource> load(String filePath) async {
    final normalizedExtension = p.extension(filePath).toLowerCase();
    if (normalizedExtension != '.csv') {
      throw const FormatException('Selecciona un archivo con extensión .csv.');
    }

    final file = File(filePath);
    final fileSizeBytes = await file.length();

    // Se procesa el archivo fila por fila desde el stream de disco, en lugar
    // de cargarlo completo en memoria: el uso de memoria queda acotado a una
    // fila a la vez sin importar el tamaño del CSV.
    List<String>? headers;
    List<bool>? columnHasValue;
    List<String?>? previewRow;
    var rowCount = 0;

    try {
      final rows = file
          .openRead()
          .transform(utf8.decoder)
          .transform(_csvDecoder);

      await for (final row in rows) {
        if (headers == null) {
          headers = _buildHeaders(row);
          columnHasValue = List<bool>.filled(headers.length, false);
          continue;
        }

        final normalizedRow = _toPreviewRow(
          row: row,
          expectedLength: headers.length,
        );
        previewRow ??= normalizedRow;
        for (var index = 0; index < headers.length; index++) {
          if (normalizedRow[index] != null) {
            columnHasValue![index] = true;
          }
        }
        rowCount++;
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(_invalidCsvMessage);
    }

    if (headers == null) {
      throw const FormatException(_emptyFileMessage);
    }

    return Datasource(
      sourcePath: filePath,
      fileName: p.basename(filePath),
      fileSizeBytes: fileSizeBytes,
      importedAt: DateTime.now().toUtc(),
      format: DatasourceFormat.csv,
      headers: headers,
      previewRow: previewRow ?? List<String?>.filled(headers.length, null),
      rowCount: rowCount,
      emptyColumnIndexes: <int>[
        for (var index = 0; index < columnHasValue!.length; index++)
          if (!columnHasValue[index]) index,
      ],
    );
  }
}

List<String> _buildHeaders(List<dynamic> headerRow) {
  if (headerRow.isEmpty) {
    throw const FormatException(_missingHeaderMessage);
  }

  final headers = headerRow
      .map((Object? cell) => cell == null ? '' : cell.toString())
      .toList(growable: false);
  if (headers.every((String header) => header.isEmpty)) {
    throw const FormatException(_missingHeaderMessage);
  }

  final duplicateHeaders = _findDuplicateHeaders(headers);
  if (duplicateHeaders.isNotEmpty) {
    throw FormatException(
      'El archivo contiene encabezados duplicados: '
      '${duplicateHeaders.join(', ')}.',
    );
  }

  return headers;
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
  required List<dynamic> row,
  required int expectedLength,
}) {
  return List<String?>.generate(expectedLength, (int index) {
    if (index >= row.length) {
      return null;
    }
    return _normalizeDataCell(row[index]);
  }, growable: false);
}

String? _normalizeDataCell(Object? value) {
  if (value == null) {
    return null;
  }

  final normalized = value.toString();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}
