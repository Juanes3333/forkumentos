import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

enum AppPhase { landing, wizard, workbench }

final workbenchEnteredProvider =
    NotifierProvider<WorkbenchEnteredNotifier, bool>(
      WorkbenchEnteredNotifier.new,
    );

final class WorkbenchEnteredNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen<String?>(
      activeProjectProvider.select((state) => state.valueOrNull?.id),
      (String? previous, String? next) {
        if (previous != next && state) {
          state = false;
        }
      },
    );
    return false;
  }

  void enterWorkbench() {
    if (!state) {
      state = true;
    }
  }
}

final appPhaseProvider = Provider<AppPhase>((ref) {
  final hasProject = ref.watch(
    activeProjectProvider.select((state) => state.valueOrNull != null),
  );
  if (!hasProject) {
    return AppPhase.landing;
  }

  if (ref.watch(workbenchEnteredProvider)) {
    return AppPhase.workbench;
  }

  return AppPhase.wizard;
});
