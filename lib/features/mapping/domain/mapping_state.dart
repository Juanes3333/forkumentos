import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mapping_state.freezed.dart';

@freezed
class MappingState with _$MappingState {
  const factory MappingState({
    required List<FieldAssignment> assignments,
    @Default(0) int currentFieldIndex,
    int? hoveredFieldIndex,
  }) = _MappingState;
}
