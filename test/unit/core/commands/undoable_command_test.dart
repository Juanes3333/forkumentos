import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/commands/undoable_command.dart';

void main() {
  test('execute y undo son inversos para un comando simple', () {
    const command = _AddValueCommand(delta: 7);
    const initialState = 12;

    final executed = command.execute(initialState);
    final undone = command.undo(executed);

    expect(executed, 19);
    expect(undone, initialState);
  });
}

final class _AddValueCommand implements UndoableCommand<int> {
  const _AddValueCommand({required this.delta});

  final int delta;

  @override
  int execute(int state) => state + delta;

  @override
  int undo(int state) => state - delta;
}
