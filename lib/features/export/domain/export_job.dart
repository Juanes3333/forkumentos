import 'package:forkumentos/features/export/domain/filename_pattern.dart';

enum ExportRangeMode { single, batch, custom }

/// How each output file gets its name.
enum FilenameMode {
  /// [ExportJob.filenamePattern] is resolved per row.
  automatic,

  /// `ExportJob.manualFilenames` provides the name; the pattern is the
  /// fallback for rows the user left blank.
  manual,
}

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
    required this.templateBaseName,
    this.customRangeText,
    this.filenameMode = FilenameMode.automatic,
    this.manualFilenames,
  });

  final String destinationFolder;
  final FilenamePattern filenamePattern;
  final ExportRangeMode rangeMode;
  final List<int> rowIndexes;
  final bool createZip;
  final String templateBaseName;
  final String? customRangeText;
  final FilenameMode filenameMode;

  /// Manual filename per export slot, keyed by position in [rowIndexes]
  /// (0 = first exported file). Only consulted when [filenameMode] is
  /// [FilenameMode.manual]; a missing/blank entry falls back to the pattern.
  final Map<int, String>? manualFilenames;
}
