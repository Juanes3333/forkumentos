import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/domain/mapping_review.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_mode.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/shared/providers/document_content_provider.dart';

final mappingWorkflowProvider =
    NotifierProvider<MappingWorkflowNotifier, MappingWorkflowState>(
      MappingWorkflowNotifier.new,
    );

final class MappingWorkflowNotifier extends Notifier<MappingWorkflowState> {
  @override
  MappingWorkflowState build() {
    ref.listen(activeMappingProvider, (previous, next) {
      _maybeAutoEnterReview(next.state.assignments.length);
    });

    return const MappingWorkflowState(
      mode: MappingWorkflowMode.mapping,
      userEnteredReview: false,
    );
  }

  void enterReview({bool userInitiated = false}) {
    state = state.copyWith(
      mode: MappingWorkflowMode.review,
      userEnteredReview: userInitiated || state.userEnteredReview,
    );
  }

  void enterMapping() {
    state = state.copyWith(mode: MappingWorkflowMode.mapping);
  }

  void _maybeAutoEnterReview(int assignmentCount) {
    if (assignmentCount == 0) {
      return;
    }

    final headers = ref.read(activeDatasourceProvider).valueOrNull?.headers;
    if (headers == null || headers.isEmpty) {
      return;
    }

    final assignedIndexes = ref
        .read(activeMappingProvider)
        .state
        .assignments
        .map((assignment) => assignment.fieldIndex)
        .toSet();
    final allMapped = List<bool>.generate(
      headers.length,
      assignedIndexes.contains,
    ).every((mapped) => mapped);

    if (allMapped && state.mode == MappingWorkflowMode.mapping) {
      state = state.copyWith(mode: MappingWorkflowMode.review);
    }
  }
}

final mappingReviewProvider = Provider<MappingReviewSnapshot?>((ref) {
  final datasource = ref.watch(activeDatasourceProvider).valueOrNull;
  if (datasource == null || datasource.headers.isEmpty) {
    return null;
  }

  final templatePath = ref
      .watch(activeTemplateProvider)
      .valueOrNull
      ?.sourcePath;
  final document = templatePath == null
      ? null
      : ref.watch(documentContentProvider(templatePath)).valueOrNull;
  final assignments = ref.watch(activeMappingProvider).state.assignments;

  return buildMappingReviewSnapshot(
    assignments: assignments,
    datasourceHeaders: datasource.headers,
    document: document,
  );
});

final exportReadinessProvider = Provider<bool>((ref) {
  return ref.watch(mappingReviewProvider)?.isExportReady ?? false;
});
