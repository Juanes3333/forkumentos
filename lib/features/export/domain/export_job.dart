import 'package:forkumentos/features/export/domain/filename_pattern.dart';

enum ExportFormat { docx, pdf, both }

enum ExportRangeMode { single, batch, custom }

/// User-configured export job (paths already resolved by the UI).
final class ExportJob {
  const ExportJob({
    required this.format,
    required this.destinationFolder,
    required this.filenamePattern,
    required this.rangeMode,
    required this.rowIndexes,
    required this.createZip,
    this.customRangeText,
  });

  final ExportFormat format;
  final String destinationFolder;
  final FilenamePattern filenamePattern;
  final ExportRangeMode rangeMode;
  final List<int> rowIndexes;
  final bool createZip;
  final String? customRangeText;
}
