/// Final outcome of an export session.
final class ExportResult {
  const ExportResult({
    required this.exportedCount,
    required this.failedCount,
    required this.skippedCount,
    required this.destinationFolder,
    required this.writtenFiles,
    this.zipPath,
    this.cancelled = false,
    this.errors = const <String>[],
  });

  final int exportedCount;
  final int failedCount;
  final int skippedCount;
  final String destinationFolder;
  final List<String> writtenFiles;
  final String? zipPath;
  final bool cancelled;
  final List<String> errors;
}
