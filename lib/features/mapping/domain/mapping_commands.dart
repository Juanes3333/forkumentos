import 'package:forkumentos/core/commands/undoable_command.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_state.dart';

final class ReplaceMappingStateCommand
    implements UndoableCommand<MappingState> {
  const ReplaceMappingStateCommand({
    required this.previous,
    required this.next,
  });

  final MappingState previous;
  final MappingState next;

  @override
  MappingState execute(MappingState state) => next;

  @override
  MappingState undo(MappingState state) => previous;
}

List<FieldAssignment> removeAssignmentsById(
  List<FieldAssignment> assignments,
  Set<String> ids,
) {
  return assignments
      .where((assignment) => !ids.contains(assignment.id))
      .toList();
}

List<FieldAssignment> removeFieldAssignments(
  List<FieldAssignment> assignments,
  int fieldIndex,
) {
  return assignments
      .where((assignment) => assignment.fieldIndex != fieldIndex)
      .toList();
}
