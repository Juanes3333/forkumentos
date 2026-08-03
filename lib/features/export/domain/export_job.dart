import 'package:forkumentos/features/export/domain/filename_pattern.dart';

enum ExportRangeMode { single, batch, custom }

/// User-configured export job (paths already resolved by the UI).
///
/// DOCX-only: exporting to PDF was removed (2026-08-03) along with PDF
/// template import, since a page-range concept never applied to DOCX (it has
/// no fixed pages until Word re-paginates it) and there is no other format
/// left to choose between.
final class ExportJob {
  const ExportJob({
    required this.destinationFolder,
    required this.filenamePattern,
    required this.rangeMode,
    required this.rowIndexes,
    required this.createZip,
    this.customRangeText,
  });

  final String destinationFolder;
  final FilenamePattern filenamePattern;
  final ExportRangeMode rangeMode;
  final List<int> rowIndexes;
  final bool createZip;
  final String? customRangeText;
}
