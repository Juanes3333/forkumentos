/// Progress snapshot for an export session.
final class ExportProgress {
  const ExportProgress({
    required this.current,
    required this.total,
    this.label,
    this.elapsed = Duration.zero,
  });

  final int current;
  final int total;
  final String? label;
  final Duration elapsed;

  double get fraction {
    if (total <= 0) {
      return 0;
    }
    return (current / total).clamp(0, 1);
  }

  int get percent => (fraction * 100).round();
}
