import 'dart:convert';

import 'package:forkumentos/core/storage/key_value_storage.dart';
import 'package:forkumentos/features/project/domain/recent_project.dart';

const _recentProjectsStorageKey = 'project.recentProjects.v1';

final class RecentProjectsStore {
  RecentProjectsStore(this._storage);

  final KeyValueStorage _storage;

  Future<List<RecentProject>> read() async {
    final rawContent = await _storage.read(_recentProjectsStorageKey);
    if (rawContent == null || rawContent.trim().isEmpty) {
      return const <RecentProject>[];
    }

    try {
      final decoded = jsonDecode(rawContent);
      if (decoded is! List) {
        return const <RecentProject>[];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RecentProject.fromJson)
          .toList();
    } on FormatException {
      return const <RecentProject>[];
    }
    // ignore: avoid_catching_errors
    on TypeError {
      return const <RecentProject>[];
    }
  }

  Future<void> write(List<RecentProject> projects) {
    final encoded = jsonEncode(
      projects.map((project) => project.toJson()).toList(),
    );
    return _storage.write(_recentProjectsStorageKey, encoded);
  }
}
