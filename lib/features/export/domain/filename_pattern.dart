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

  /// Joins non-empty resolved blocks (unless a neighbor already has a
  /// separator).
  static const String blockSeparator = '_';

  static const FilenamePattern defaultPattern = FilenamePattern(
    blocks: <FilenamePatternBlock>[FilenameTextBlock('documento')],
  );

  static final RegExp _edgeSeparator = RegExp(r'[_\-]\s*$');
  static final RegExp _leadingSeparator = RegExp(r'^\s*[_\-]');

  /// Resolves the pattern against a sample/export row (live preview).
  String resolve({required List<String?> row, required List<String> headers}) {
    final parts = <String>[];
    for (final block in blocks) {
      final part = switch (block) {
        FilenameTextBlock(:final text) => text,
        FilenameFieldBlock(:final fieldIndex) =>
          fieldIndex >= 0 && fieldIndex < row.length
              ? (row[fieldIndex] ?? '')
              : fieldIndex >= 0 && fieldIndex < headers.length
              ? headers[fieldIndex]
              : '',
      };
      if (part.isNotEmpty) {
        parts.add(part);
      }
    }

    if (parts.isEmpty) {
      return sanitize('');
    }

    final buffer = StringBuffer(parts.first);
    for (var index = 1; index < parts.length; index++) {
      final previous = buffer.toString();
      final next = parts[index];
      if (_needsBlockSeparator(previous, next)) {
        buffer.write(blockSeparator);
      }
      buffer.write(next);
    }
    return sanitize(buffer.toString());
  }

  /// Insert `_` only when neither side already carries `_` or `-`.
  static bool _needsBlockSeparator(String previous, String next) {
    if (_edgeSeparator.hasMatch(previous) || _leadingSeparator.hasMatch(next)) {
      return false;
    }
    return true;
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
