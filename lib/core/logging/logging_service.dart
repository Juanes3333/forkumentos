abstract interface class LoggingService {
  void debug(String message, {String? module});

  void info(String message, {String? module});

  void warning(
    String message, {
    String? module,
    Object? error,
    StackTrace? stackTrace,
  });

  void error(
    String message, {
    String? module,
    Object? error,
    StackTrace? stackTrace,
  });
}
