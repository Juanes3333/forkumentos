import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/app_logger.dart';
import 'package:logger/logger.dart';

void main() {
  test('AppLogger enruta mensajes al logger subyacente', () {
    final output = _MemoryLogOutput();
    final logger = Logger(
      printer: SimplePrinter(),
      output: output,
      level: Level.trace,
    );
    final appLogger = AppLogger(logger: logger);

    expect(() {
      appLogger
        ..debug('debug message', module: 'Test')
        ..info('info message', module: 'Test')
        ..warning('warning message', module: 'Test')
        ..error('error message', module: 'Test');
    }, returnsNormally);

    final renderedOutput = output.lines.join('\n');
    expect(renderedOutput, contains('[Test] debug message'));
    expect(renderedOutput, contains('[Test] info message'));
    expect(renderedOutput, contains('[Test] warning message'));
    expect(renderedOutput, contains('[Test] error message'));
  });
}

final class _MemoryLogOutput extends LogOutput {
  final List<String> lines = <String>[];

  @override
  void output(OutputEvent event) {
    lines.addAll(event.lines);
  }
}
