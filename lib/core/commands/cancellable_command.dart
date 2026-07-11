/// Generic cancellable command with progress events.
///
/// Feature-specific progress/result types live in their own domains.
abstract class CancellableCommand<R> {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }

  Future<R> execute({void Function(CommandProgressEvent event)? onProgress});
}

/// Generic progress pulse for long-running commands.
final class CommandProgressEvent {
  const CommandProgressEvent({
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
