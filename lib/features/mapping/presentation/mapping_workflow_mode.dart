enum MappingWorkflowMode { mapping, review }

final class MappingWorkflowState {
  const MappingWorkflowState({
    required this.mode,
    required this.userEnteredReview,
  });

  final MappingWorkflowMode mode;
  final bool userEnteredReview;

  MappingWorkflowState copyWith({
    MappingWorkflowMode? mode,
    bool? userEnteredReview,
  }) {
    return MappingWorkflowState(
      mode: mode ?? this.mode,
      userEnteredReview: userEnteredReview ?? this.userEnteredReview,
    );
  }
}
