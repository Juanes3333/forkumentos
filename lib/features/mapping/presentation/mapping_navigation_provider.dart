import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

sealed class MappingNavigationTarget {
  const MappingNavigationTarget();
}

final class DatasourceFieldNavigationTarget extends MappingNavigationTarget {
  const DatasourceFieldNavigationTarget(this.fieldIndex);

  final int fieldIndex;
}

final class AssignmentNavigationTarget extends MappingNavigationTarget {
  const AssignmentNavigationTarget(this.assignmentId);

  final String assignmentId;
}

final class DocumentPlaceholderNavigationTarget
    extends MappingNavigationTarget {
  const DocumentPlaceholderNavigationTarget({
    required this.path,
    required this.previewText,
  });

  final DocumentTextPath path;
  final String previewText;
}

final class MappingNavigationRequest {
  const MappingNavigationRequest({required this.token, required this.target});

  final int token;
  final MappingNavigationTarget target;
}

final mappingNavigationProvider =
    NotifierProvider<MappingNavigationNotifier, MappingNavigationRequest?>(
      MappingNavigationNotifier.new,
    );

final class MappingNavigationNotifier
    extends Notifier<MappingNavigationRequest?> {
  var _token = 0;

  @override
  MappingNavigationRequest? build() => null;

  void navigateTo(MappingNavigationTarget target) {
    _token++;
    state = MappingNavigationRequest(token: _token, target: target);
  }

  void clear() {
    state = null;
  }
}

final emphasizedAssignmentIdProvider = StateProvider<String?>((ref) => null);
