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

  /// Carpeta donde la app guarda el Excel de un proyecto (el que el cliente
  /// edita). Lleva el id corto del proyecto para que dos proyectos con el
  /// mismo nombre no compartan archivo.
  String managedDatasourceFolder({
    required String projectName,
    required String projectId,
  }) {
    final safeName = projectName
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .trim();
    final shortId = projectId.length > 8
        ? projectId.substring(0, 8)
        : projectId;
    return p.join(
      workspace,
      '${safeName.isEmpty ? 'Proyecto' : safeName}-$shortId',
    );
  }

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
