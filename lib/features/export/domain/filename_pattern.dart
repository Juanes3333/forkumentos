/// Visual filename builder: literal text blocks and datasource field blocks.
sealed class FilenamePatternBlock {
  const FilenamePatternBlock();
}

final class FilenameTextBlock extends FilenamePatternBlock {
  const FilenameTextBlock(this.text);

  final String text;
}

final class FilenameFieldBlock extends FilenamePatternBlock {
  const FilenameFieldBlock({
    required this.fieldIndex,
    required this.fieldHeader,
  });

  final int fieldIndex;
  final String fieldHeader;
}

final class FilenamePattern {
  const FilenamePattern({required this.blocks});

  final List<FilenamePatternBlock> blocks;

  static const FilenamePattern defaultPattern = FilenamePattern(
    blocks: <FilenamePatternBlock>[FilenameTextBlock('documento')],
  );

  /// Resolves the pattern against a sample/export row (live preview).
  String resolve({required List<String?> row, required List<String> headers}) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      switch (block) {
        case FilenameTextBlock(:final text):
          buffer.write(text);
        case FilenameFieldBlock(:final fieldIndex):
          if (fieldIndex >= 0 && fieldIndex < row.length) {
            buffer.write(row[fieldIndex] ?? '');
          } else if (fieldIndex >= 0 && fieldIndex < headers.length) {
            buffer.write(headers[fieldIndex]);
          }
      }
    }
    return sanitize(buffer.toString());
  }

  /// Removes invalid filename characters and trims spaces/dots.
  static String sanitize(String raw) {
    var value = raw.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    value = value.replaceAll(RegExp(r'\.+$'), '').trim();
    if (value.isEmpty) {
      return 'documento';
    }
    return value;
  }

  /// Appends `(2)`, `(3)`, … on collision — never silent overwrite.
  static String dedupe(String baseName, Set<String> usedLowerNames) {
    final sanitized = sanitize(baseName);
    var candidate = sanitized;
    var suffix = 2;
    while (usedLowerNames.contains(candidate.toLowerCase())) {
      candidate = '$sanitized ($suffix)';
      suffix++;
    }
    return candidate;
  }
}
