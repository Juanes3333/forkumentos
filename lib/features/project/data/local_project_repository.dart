import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:path/path.dart' as p;

const _manifestFileName = 'manifest.json';
const _projectFileName = 'project.json';
const _mappingsFileName = 'mappings.json';
const _templateDirName = 'template';
const _datasourceDirName = 'datasource';
const _manifestVersion = 1;

final class LocalProjectRepository implements ProjectRepository {
  const LocalProjectRepository();

  @override
  Future<Project> load(
    String filePath, {
    required String cacheDirectory,
  }) async {
    if (!filePath.toLowerCase().endsWith(projectFileExtension)) {
      throw const FormatException(
        'El archivo debe tener extensión .fork. '
        'Los proyectos .forkumentos.json ya no son compatibles.',
      );
    }

    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Old JSON format detection (plain text starting with '{').
    if (_looksLikeLegacyJson(bytes)) {
      throw const FormatException(
        'Este archivo usa el formato antiguo (.forkumentos.json). '
        'Abre o vuelve a guardar el proyecto como .fork.',
      );
    }

    final extracted = await Isolate.run(
      () => _decodeAndExtractInIsolate(
        _IsolateLoadRequest(
          bytes: Uint8List.fromList(bytes),
          cacheDirectory: cacheDirectory,
        ),
      ),
    );

    final project = Project.fromJson({
      ...extracted.projectJson,
      'mappingAssignments': extracted.mappingAssignments,
    });

    return project.copyWith(
      filePath: filePath,
      isDirty: false,
      embeddedTemplatePath: extracted.embeddedTemplatePath,
      embeddedDatasourcePath: extracted.embeddedDatasourcePath,
    );
  }

  @override
  Future<Project> save({
    required Project project,
    required String filePath,
    String? templateSourcePath,
    String? datasourceSourcePath,
    String? cacheDirectory,
  }) async {
    final now = DateTime.now().toUtc();
    final archive = Archive()
      ..addFile(
        _utf8File(
          _manifestFileName,
          jsonEncode(<String, dynamic>{'version': _manifestVersion}),
        ),
      );

    final projectPayload = <String, dynamic>{
      'id': project.id,
      'name': project.name,
      'createdAt': project.createdAt.toUtc().toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    archive
      ..addFile(_utf8File(_projectFileName, jsonEncode(projectPayload)))
      ..addFile(
        _utf8File(_mappingsFileName, jsonEncode(project.mappingAssignments)),
      );

    var embeddedTemplatePath = project.embeddedTemplatePath;
    var embeddedDatasourcePath = project.embeddedDatasourcePath;

    final resolvedTemplate = templateSourcePath ?? project.embeddedTemplatePath;
    if (resolvedTemplate != null && resolvedTemplate.isNotEmpty) {
      final fileName = p.basename(resolvedTemplate);
      final bytes = await File(resolvedTemplate).readAsBytes();
      archive.addFile(
        ArchiveFile('$_templateDirName/$fileName', bytes.length, bytes),
      );
      if (cacheDirectory != null) {
        embeddedTemplatePath = await _copyIntoCache(
          sourcePath: resolvedTemplate,
          cacheDirectory: cacheDirectory,
          projectId: project.id,
          kind: _templateDirName,
        );
      } else {
        embeddedTemplatePath = resolvedTemplate;
      }
    }

    final resolvedDatasource =
        datasourceSourcePath ?? project.embeddedDatasourcePath;
    if (resolvedDatasource != null && resolvedDatasource.isNotEmpty) {
      final fileName = p.basename(resolvedDatasource);
      final bytes = await File(resolvedDatasource).readAsBytes();
      archive.addFile(
        ArchiveFile('$_datasourceDirName/$fileName', bytes.length, bytes),
      );
      if (cacheDirectory != null) {
        embeddedDatasourcePath = await _copyIntoCache(
          sourcePath: resolvedDatasource,
          cacheDirectory: cacheDirectory,
          projectId: project.id,
          kind: _datasourceDirName,
        );
      } else {
        embeddedDatasourcePath = resolvedDatasource;
      }
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw const FileSystemException('No se pudo codificar el archivo .fork.');
    }

    final tempFilePath = p.join(
      p.dirname(filePath),
      '.${p.basename(filePath)}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    final tempFile = File(tempFilePath);

    try {
      await Directory(p.dirname(filePath)).create(recursive: true);
      await tempFile.writeAsBytes(encoded, flush: true);
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

    return project.copyWith(
      filePath: filePath,
      updatedAt: now,
      isDirty: false,
      embeddedTemplatePath: embeddedTemplatePath,
      embeddedDatasourcePath: embeddedDatasourcePath,
    );
  }

  bool _looksLikeLegacyJson(List<int> bytes) {
    for (final byte in bytes) {
      if (byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D) {
        continue;
      }
      return byte == 0x7B; // '{'
    }
    return false;
  }

  Future<String> _copyIntoCache({
    required String sourcePath,
    required String cacheDirectory,
    required String projectId,
    required String kind,
  }) async {
    final destDir = p.join(cacheDirectory, projectId, kind);
    await Directory(destDir).create(recursive: true);
    final destPath = p.join(destDir, p.basename(sourcePath));
    if (p.equals(sourcePath, destPath)) {
      return destPath;
    }
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  ArchiveFile _utf8File(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
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
      final backupFile = File('$targetPath.bak');

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
        // ignore: avoid_slow_async_io
        if (await backupFile.exists() && !await targetFile.exists()) {
          await backupFile.rename(targetPath);
        }
        rethrow;
      }

      // ignore: avoid_slow_async_io
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    }
  }
}

final class _IsolateLoadRequest {
  const _IsolateLoadRequest({
    required this.bytes,
    required this.cacheDirectory,
  });

  final Uint8List bytes;
  final String cacheDirectory;
}

final class _IsolateLoadResult {
  const _IsolateLoadResult({
    required this.projectJson,
    required this.mappingAssignments,
    this.embeddedTemplatePath,
    this.embeddedDatasourcePath,
  });

  final Map<String, dynamic> projectJson;
  final List<Map<String, dynamic>> mappingAssignments;
  final String? embeddedTemplatePath;
  final String? embeddedDatasourcePath;
}

_IsolateLoadResult _decodeAndExtractInIsolate(_IsolateLoadRequest request) {
  late final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(request.bytes, verify: true);
  } on Object {
    throw const FormatException(
      'El archivo .fork no es un ZIP válido o está dañado.',
    );
  }

  final manifestRaw = _readArchiveText(archive, _manifestFileName);
  if (manifestRaw == null) {
    throw const FormatException(
      'El archivo .fork no contiene un manifiesto válido.',
    );
  }

  final manifest = _decodeObject(manifestRaw, 'manifiesto');
  final version = manifest['version'];
  if (version != _manifestVersion) {
    throw FormatException('Versión de proyecto no soportada: $version.');
  }

  final projectRaw = _readArchiveText(archive, _projectFileName);
  if (projectRaw == null) {
    throw const FormatException('El archivo .fork no contiene project.json.');
  }

  final projectJson = _decodeObject(projectRaw, 'project.json');
  final mappingsRaw = _readArchiveText(archive, _mappingsFileName);
  final mappingAssignments = <Map<String, dynamic>>[];
  if (mappingsRaw != null && mappingsRaw.trim().isNotEmpty) {
    final decoded = jsonDecode(mappingsRaw);
    if (decoded is! List) {
      throw const FormatException('mappings.json debe ser una lista JSON.');
    }
    for (final item in decoded) {
      if (item is Map) {
        mappingAssignments.add(item.cast<String, dynamic>());
      }
    }
  }

  final projectId = projectJson['id'] as String?;
  if (projectId == null || projectId.isEmpty) {
    throw const FormatException('project.json no contiene un id válido.');
  }

  final extractRoot = p.join(request.cacheDirectory, projectId);
  Directory(extractRoot).createSync(recursive: true);

  final embeddedTemplatePath = _extractSingleArtifactSync(
    archive: archive,
    dirPrefix: '$_templateDirName/',
    destinationDir: p.join(extractRoot, _templateDirName),
  );
  final embeddedDatasourcePath = _extractSingleArtifactSync(
    archive: archive,
    dirPrefix: '$_datasourceDirName/',
    destinationDir: p.join(extractRoot, _datasourceDirName),
  );

  return _IsolateLoadResult(
    projectJson: projectJson,
    mappingAssignments: mappingAssignments,
    embeddedTemplatePath: embeddedTemplatePath,
    embeddedDatasourcePath: embeddedDatasourcePath,
  );
}

Map<String, dynamic> _decodeObject(String raw, String label) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw FormatException('El $label debe ser un objeto JSON.');
  }
  return decoded.cast<String, dynamic>();
}

String? _readArchiveText(Archive archive, String name) {
  final file = archive.findFile(name);
  if (file == null) {
    return null;
  }
  return utf8.decode(file.content as List<int>);
}

String? _extractSingleArtifactSync({
  required Archive archive,
  required String dirPrefix,
  required String destinationDir,
}) {
  ArchiveFile? match;
  for (final file in archive.files) {
    if (!file.isFile) {
      continue;
    }
    if (!file.name.startsWith(dirPrefix)) {
      continue;
    }
    final relative = file.name.substring(dirPrefix.length);
    if (relative.isEmpty || relative.contains('/')) {
      continue;
    }
    match = file;
    break;
  }
  if (match == null) {
    return null;
  }

  Directory(destinationDir).createSync(recursive: true);
  final outPath = p.join(destinationDir, p.basename(match.name));
  File(outPath).writeAsBytesSync(match.content as List<int>, flush: true);
  return outPath;
}
