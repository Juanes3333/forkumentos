import 'dart:convert';
import 'dart:io';

import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:path/path.dart' as p;

final class LocalProjectRepository implements ProjectRepository {
  const LocalProjectRepository();

  @override
  Future<Project> load(String filePath) async {
    final rawContent = await File(filePath).readAsString();
    final decoded = jsonDecode(rawContent);
    if (decoded is! Map) {
      throw const FormatException(
        'El archivo del proyecto debe contener un objeto JSON.',
      );
    }

    final project = Project.fromJson(decoded.cast<String, dynamic>());
    return project.copyWith(filePath: filePath);
  }

  @override
  Future<Project> save({
    required Project project,
    required String filePath,
  }) async {
    final projectToPersist = project.copyWith(
      updatedAt: DateTime.now().toUtc(),
      filePath: null,
    );

    final encodedProject = const JsonEncoder.withIndent(
      '  ',
    ).convert(projectToPersist.toJson());

    final tempFilePath = p.join(
      p.dirname(filePath),
      '.${p.basename(filePath)}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    final tempFile = File(tempFilePath);

    try {
      await tempFile.writeAsString(encodedProject, flush: true);
      await _replaceTargetWithTempFile(
        tempFile: tempFile,
        targetPath: filePath,
      );
    } catch (_) {
      // ignore: avoid_slow_async_io
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }

    return projectToPersist.copyWith(filePath: filePath);
  }

  Future<void> _replaceTargetWithTempFile({
    required File tempFile,
    required String targetPath,
  }) async {
    try {
      await tempFile.rename(targetPath);
      return;
    } on FileSystemException {
      final targetFile = File(targetPath);
      final backupFile = File(_buildBackupPath(targetPath));

      // ignore: avoid_slow_async_io
      if (!await targetFile.exists()) {
        rethrow;
      }

      // ignore: avoid_slow_async_io
      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      await targetFile.rename(backupFile.path);
      try {
        await tempFile.rename(targetPath);
      } on FileSystemException {
        await _restoreBackupFile(
          backupFile: backupFile,
          targetPath: targetPath,
        );
        rethrow;
      }

      // ignore: avoid_slow_async_io
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    }
  }

  String _buildBackupPath(String targetPath) => '$targetPath.bak';

  Future<void> _restoreBackupFile({
    required File backupFile,
    required String targetPath,
  }) async {
    // ignore: avoid_slow_async_io
    if (!await backupFile.exists()) {
      return;
    }

    final targetFile = File(targetPath);
    // ignore: avoid_slow_async_io
    if (await targetFile.exists()) {
      return;
    }

    await backupFile.rename(targetPath);
  }
}
