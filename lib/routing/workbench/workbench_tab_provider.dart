import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_tab.dart';

final workbenchTabProvider =
    NotifierProvider<WorkbenchTabNotifier, WorkbenchTab>(
      WorkbenchTabNotifier.new,
    );

final class WorkbenchTabNotifier extends Notifier<WorkbenchTab> {
  @override
  WorkbenchTab build() {
    return WorkbenchTab.home;
  }

  void selectTab(WorkbenchTab tab) {
    state = tab;
    final workflow = ref.read(mappingWorkflowProvider.notifier);
    if (tab == WorkbenchTab.mapping) {
      workflow.enterMapping();
    } else if (tab == WorkbenchTab.review) {
      workflow.enterReview(userInitiated: true);
    }
  }
}
