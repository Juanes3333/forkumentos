import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves and ensures the user-visible Forkumentos workspace tree.
final class WorkspacePaths {
  WorkspacePaths({required this.root});

  final String root;

  String get projects => p.join(root, 'Projects');
  String get exports => p.join(root, 'Exports');
  String get workspace => p.join(root, 'Workspace');
  String get cache => p.join(root, 'Cache');
  String get logs => p.join(root, 'Logs');

  String projectCache(String projectId) => p.join(cache, projectId);

  String exportFolder(String projectName) => p.join(exports, projectName);

  String defaultProjectFile(String projectName) =>
      p.join(projects, '$projectName.fork');

  /// Creates missing folders. Never throws for already-existing dirs.
  Future<void> ensureAll() async {
    for (final path in <String>[
      root,
      projects,
      exports,
      workspace,
      cache,
      logs,
    ]) {
      await Directory(path).create(recursive: true);
    }
  }

  Future<void> ensureExportFolder(String projectName) async {
    await Directory(exportFolder(projectName)).create(recursive: true);
  }

  Future<void> ensureProjectCache(String projectId) async {
    await Directory(projectCache(projectId)).create(recursive: true);
  }

  static Future<String> defaultRoot() async {
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, 'Forkumentos');
  }

  /// Next unused "Project N" / "Proyecto N" style name under Projects/.
  Future<String> nextAutomaticProjectName({String prefix = 'Proyecto'}) async {
    await Directory(projects).create(recursive: true);
    var index = 1;
    while (true) {
      final candidate = '$prefix $index';
      final forkPath = defaultProjectFile(candidate);
      // ignore: avoid_slow_async_io
      if (!await File(forkPath).exists()) {
        return candidate;
      }
      index++;
    }
  }
}
