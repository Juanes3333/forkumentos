import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/project/data/recent_projects_store.dart';
import 'package:forkumentos/features/project/data/recent_projects_store_provider.dart';
import 'package:forkumentos/features/project/domain/recent_project.dart';

const _maxRecentProjects = 10;

final recentProjectsProvider =
    AsyncNotifierProvider<RecentProjectsNotifier, List<RecentProject>>(
      RecentProjectsNotifier.new,
    );

final class RecentProjectsNotifier extends AsyncNotifier<List<RecentProject>> {
  @override
  FutureOr<List<RecentProject>> build() {
    return _store.read();
  }

  Future<void> record({required String filePath, required String name}) async {
    final currentEntries = state.valueOrNull ?? await _store.read();

    final updatedEntries = <RecentProject>[
      RecentProject(
        filePath: filePath,
        name: name,
        lastOpenedAt: DateTime.now().toUtc(),
      ),
      ...currentEntries.where((entry) => entry.filePath != filePath),
    ].take(_maxRecentProjects).toList();

    await _store.write(updatedEntries);
    state = AsyncData(updatedEntries);
  }

  RecentProjectsStore get _store => ref.read(recentProjectsStoreProvider);
}
