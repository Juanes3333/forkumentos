import 'package:forkumentos/features/export/domain/filename_pattern.dart';

enum ExportFormat { docx, pdf, both }

enum ExportRangeMode { single, batch, custom }

/// Which pages of the source template are exported (PDF-only; DOCX always
/// preserves the full template structure).
enum ExportPageRangeMode { all, custom }

/// User-configured export job (paths already resolved by the UI).
final class ExportJob {
  const ExportJob({
    required this.format,
    required this.destinationFolder,
    required this.filenamePattern,
    required this.rangeMode,
    required this.rowIndexes,
    required this.createZip,
    required this.pageRangeMode,
    this.customRangeText,
    this.pageIndexes,
    this.customPageRangeText,
  });

  final ExportFormat format;
  final String destinationFolder;
  final FilenamePattern filenamePattern;
  final ExportRangeMode rangeMode;
  final List<int> rowIndexes;
  final bool createZip;
  final String? customRangeText;

  /// Page selection mode (PDF export only).
  final ExportPageRangeMode pageRangeMode;

  /// `null` when [pageRangeMode] is `all` (no filtering); ordered 0-based
  /// page indexes when `custom`.
  final List<int>? pageIndexes;
  final String? customPageRangeText;
}
