/// Parses spreadsheet-style row ranges into sorted unique 0-based indexes.
///
/// Input is 1-based (e.g. `"1-20,15,18-25"`). Invalid tokens throw
/// [FormatException]. Indexes outside `[1, rowCount]` are clamped.
final class ExportRowRange {
  const ExportRowRange._();

  /// Parses [input] into ascending unique 0-based row indexes.
  ///
  /// Empty / whitespace-only input yields an empty list.
  static List<int> parse(String input, {required int rowCount}) {
    if (rowCount <= 0) {
      return const <int>[];
    }

    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const <int>[];
    }

    final indexes = <int>{};
    for (final token in trimmed.split(',')) {
      final part = token.trim();
      if (part.isEmpty) {
        throw const FormatException('Rango vacío entre comas.');
      }

      final dashIndex = part.indexOf('-');
      if (dashIndex < 0) {
        indexes.add(_parseSingle(part, rowCount: rowCount));
        continue;
      }

      if (dashIndex == 0 || dashIndex == part.length - 1) {
        throw FormatException('Rango inválido: "$part".');
      }

      final start = _parseSingle(
        part.substring(0, dashIndex),
        rowCount: rowCount,
      );
      final end = _parseSingle(
        part.substring(dashIndex + 1),
        rowCount: rowCount,
      );
      final from = start <= end ? start : end;
      final to = start <= end ? end : start;
      for (var index = from; index <= to; index++) {
        indexes.add(index);
      }
    }

    final sorted = indexes.toList()..sort();
    return sorted;
  }

  static int _parseSingle(String raw, {required int rowCount}) {
    final value = int.tryParse(raw.trim());
    if (value == null) {
      throw FormatException('Número de fila inválido: "$raw".');
    }
    if (value < 1) {
      throw FormatException('Las filas empiezan en 1: "$raw".');
    }

    final oneBased = value.clamp(1, rowCount);
    return oneBased - 1;
  }
}
