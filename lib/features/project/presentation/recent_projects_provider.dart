import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/project/data/recent_projects_store.dart';
import 'package:forkumentos/features/project/data/recent_projects_store_provider.dart';
import 'package:forkumentos/features/project/domain/recent_project.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';

final recentProjectsProvider =
    AsyncNotifierProvider<RecentProjectsNotifier, List<RecentProject>>(
      RecentProjectsNotifier.new,
    );

final class RecentProjectsNotifier extends AsyncNotifier<List<RecentProject>> {
  @override
  FutureOr<List<RecentProject>> build() async {
    final entries = await _store.read();
    return _pruneMissing(entries);
  }

  Future<void> record({required String filePath, required String name}) async {
    final currentEntries = state.valueOrNull ?? await _store.read();
    final limit = ref.read(recentProjectsLimitProvider);

    final updatedEntries = <RecentProject>[
      RecentProject(
        filePath: filePath,
        name: name,
        lastOpenedAt: DateTime.now().toUtc(),
      ),
      ...currentEntries.where((entry) => entry.filePath != filePath),
    ].take(limit).toList();

    await _store.write(updatedEntries);
    state = AsyncData(updatedEntries);
  }

  Future<void> remove(String filePath) async {
    final currentEntries = state.valueOrNull ?? await _store.read();
    final updatedEntries = currentEntries
        .where((entry) => entry.filePath != filePath)
        .toList();
    await _store.write(updatedEntries);
    state = AsyncData(updatedEntries);
  }

  Future<void> clear() async {
    await _store.write(const <RecentProject>[]);
    state = const AsyncData(<RecentProject>[]);
  }

  /// Drops entries whose files no longer exist and persists if changed.
  Future<List<RecentProject>> pruneMissing() async {
    final currentEntries = state.valueOrNull ?? await _store.read();
    final pruned = await _pruneMissing(currentEntries);
    state = AsyncData(pruned);
    return pruned;
  }

  Future<List<RecentProject>> _pruneMissing(List<RecentProject> entries) async {
    final existing = <RecentProject>[];
    var changed = false;
    for (final entry in entries) {
      // ignore: avoid_slow_async_io
      if (await File(entry.filePath).exists()) {
        existing.add(entry);
      } else {
        changed = true;
      }
    }
    if (changed) {
      await _store.write(existing);
    }
    return existing;
  }

  RecentProjectsStore get _store => ref.read(recentProjectsStoreProvider);
}
