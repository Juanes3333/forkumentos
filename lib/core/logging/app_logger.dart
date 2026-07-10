import 'package:forkumentos/core/logging/logging_service.dart';
import 'package:logger/logger.dart';

final class AppLogger implements LoggingService {
  AppLogger({Logger? logger})
    : _logger =
          logger ??
          Logger(
            level: Level.trace,
            printer: SimplePrinter(printTime: true, colors: false),
            output: ConsoleOutput(),
          );

  final Logger _logger;

  @override
  void debug(String message, {String? module}) {
    _logger.d(_formatMessage(message, module));
  }

  @override
  void info(String message, {String? module}) {
    _logger.i(_formatMessage(message, module));
  }

  @override
  void warning(
    String message, {
    String? module,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.w(
      _formatMessage(message, module),
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void error(
    String message, {
    String? module,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.e(
      _formatMessage(message, module),
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _formatMessage(String message, String? module) {
    if (module == null || module.isEmpty) {
      return message;
    }

    return '[$module] $message';
  }
}
