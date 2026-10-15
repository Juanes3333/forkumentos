import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/project/domain/project_template.dart';
import 'package:path/path.dart' as p;

const _manifestFileName = 'manifest.json';
const _projectFileName = 'project.json';
const _mappingsFileName = 'mappings.json';
const _templateDirName = 'template';
const _datasourceDirName = 'datasource';
const _manifestVersion = 1;
const _multiTemplateManifestVersion = 2;
const _readAttempts = 3;
const _readRetryDelay = Duration(milliseconds: 250);

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
      templates: <ProjectTemplate>[
        for (final template in extracted.templates)
          ProjectTemplate(
            id: template.id,
            fileName: template.fileName,
            embeddedPath: template.embeddedPath,
            assignments: template.assignments,
          ),
      ],
      activeTemplateId: extracted.activeTemplateId,
      embeddedTemplatePath: extracted.embeddedTemplatePath,
      embeddedDatasourcePath: extracted.embeddedDatasourcePath,
      // Absent in projects saved before this field existed; null is the
      // correct, backward-compatible result in that case.
      datasourceExternalPath:
          extracted.projectJson['datasourceExternalPath'] as String?,
      datasourceSyncedMtimeMs:
          (extracted.projectJson['datasourceSyncedMtimeMs'] as num?)?.toInt(),
      datasourceSyncedSizeBytes:
          (extracted.projectJson['datasourceSyncedSizeBytes'] as num?)?.toInt(),
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
    // Con una sola plantilla se sigue escribiendo el formato v1 (lo abren
    // también las versiones anteriores); v2 solo con varias plantillas.
    final multiTemplate = project.templates.length >= 2;
    final archive = Archive()
      ..addFile(
        _utf8File(
          _manifestFileName,
          jsonEncode(<String, dynamic>{
            'version': multiTemplate
                ? _multiTemplateManifestVersion
                : _manifestVersion,
          }),
        ),
      );

    final projectPayload = <String, dynamic>{
      if (multiTemplate) ...<String, dynamic>{
        'activeTemplateId': project.activeTemplateId,
        'templates': <Map<String, dynamic>>[
          for (final template in project.templates)
            <String, dynamic>{
              'id': template.id,
              'fileName': template.fileName,
              'assignments': template.id == project.activeTemplateId
                  ? project.mappingAssignments
                  : template.assignments,
            },
        ],
      },
      'id': project.id,
      'name': project.name,
      'createdAt': project.createdAt.toUtc().toIso8601String(),
      'updatedAt': now.toIso8601String(),
      if (project.datasourceExternalPath != null)
        'datasourceExternalPath': project.datasourceExternalPath,
      if (project.datasourceSyncedMtimeMs != null)
        'datasourceSyncedMtimeMs': project.datasourceSyncedMtimeMs,
      if (project.datasourceSyncedSizeBytes != null)
        'datasourceSyncedSizeBytes': project.datasourceSyncedSizeBytes,
    };
    archive
      ..addFile(_utf8File(_projectFileName, jsonEncode(projectPayload)))
      ..addFile(
        _utf8File(_mappingsFileName, jsonEncode(project.mappingAssignments)),
      );

    var embeddedTemplatePath = project.embeddedTemplatePath;
    var embeddedDatasourcePath = project.embeddedDatasourcePath;
    var savedTemplates = project.templates;

    final resolvedTemplate = templateSourcePath ?? project.embeddedTemplatePath;
    if (multiTemplate) {
      savedTemplates = <ProjectTemplate>[];
      for (final template in project.templates) {
        final isActive = template.id == project.activeTemplateId;
        final source = isActive ? resolvedTemplate : template.embeddedPath;
        if (source == null || source.isEmpty || !File(source).existsSync()) {
          savedTemplates.add(template);
          continue;
        }
        final bytes = await File(source).readAsBytes();
        archive.addFile(
          ArchiveFile(
            '$_templateDirName/${template.id}/${template.fileName}',
            bytes.length,
            bytes,
          ),
        );
        final cached = cacheDirectory == null
            ? source
            : await _copyIntoCache(
                sourcePath: source,
                cacheDirectory: cacheDirectory,
                projectId: project.id,
                kind: p.join(_templateDirName, template.id),
              );
        savedTemplates.add(template.copyWith(embeddedPath: cached));
        if (isActive) {
          embeddedTemplatePath = cached;
        }
      }
    } else if (resolvedTemplate != null && resolvedTemplate.isNotEmpty) {
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
      final read = await _readDatasourceBytes(
        path: resolvedDatasource,
        snapshotPath: cacheDirectory == null
            ? null
            : p.join(cacheDirectory, project.id, _datasourceDirName, fileName),
      );
      final bytes = read.bytes;
      archive.addFile(
        ArchiveFile('$_datasourceDirName/$fileName', bytes.length, bytes),
      );
      if (read.fromSnapshotPath != null) {
        // El archivo no se pudo leer: lo embebido es la copia de la caché, que
        // ya está donde debe; no hay nada que copiar.
        embeddedDatasourcePath = read.fromSnapshotPath;
      } else if (cacheDirectory != null) {
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
      templates: savedTemplates,
      embeddedTemplatePath: embeddedTemplatePath,
      embeddedDatasourcePath: embeddedDatasourcePath,
    );
  }

  /// Lee el Excel que se va a embeber. Guardar el proyecto nunca debe fallar
  /// porque el archivo esté bloqueado un instante (Excel guardando, antivirus,
  /// OneDrive) o ya no exista: se reintenta unas veces y, si sigue sin
  /// poderse leer, se usa la última copia embebida en la caché del proyecto.
  Future<({List<int> bytes, String? fromSnapshotPath})> _readDatasourceBytes({
    required String path,
    required String? snapshotPath,
  }) async {
    FileSystemException? lastError;
    for (var attempt = 0; attempt < _readAttempts; attempt++) {
      try {
        return (bytes: await File(path).readAsBytes(), fromSnapshotPath: null);
      } on FileSystemException catch (error) {
        lastError = error;
        if (attempt < _readAttempts - 1) {
          await Future<void>.delayed(_readRetryDelay);
        }
      }
    }
    if (snapshotPath != null && !p.equals(snapshotPath, path)) {
      final snapshot = File(snapshotPath);
      // ignore: avoid_slow_async_io
      if (await snapshot.exists()) {
        return (
          bytes: await snapshot.readAsBytes(),
          fromSnapshotPath: snapshotPath,
        );
      }
    }
    throw lastError!;
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

final class _LoadedTemplate {
  const _LoadedTemplate({
    required this.id,
    required this.fileName,
    required this.assignments,
    this.embeddedPath,
  });

  final String id;
  final String fileName;
  final String? embeddedPath;
  final List<Map<String, dynamic>> assignments;
}

final class _IsolateLoadResult {
  const _IsolateLoadResult({
    required this.projectJson,
    required this.mappingAssignments,
    this.templates = const <_LoadedTemplate>[],
    this.activeTemplateId,
    this.embeddedTemplatePath,
    this.embeddedDatasourcePath,
  });

  final Map<String, dynamic> projectJson;
  final List<Map<String, dynamic>> mappingAssignments;
  final List<_LoadedTemplate> templates;
  final String? activeTemplateId;
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
  if (version != _manifestVersion && version != _multiTemplateManifestVersion) {
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

  final templates = <_LoadedTemplate>[];
  String? activeTemplateId;
  String? embeddedTemplatePath;
  final rawTemplates = projectJson['templates'];
  if (version == _multiTemplateManifestVersion && rawTemplates is List) {
    activeTemplateId = projectJson['activeTemplateId'] as String?;
    for (final raw in rawTemplates) {
      if (raw is! Map) {
        continue;
      }
      final id = raw['id'] as String?;
      final fileName = raw['fileName'] as String?;
      if (id == null || id.isEmpty || fileName == null) {
        continue;
      }
      final entry = archive.findFile('$_templateDirName/$id/$fileName');
      String? embeddedPath;
      if (entry != null && entry.isFile) {
        final destination = p.join(extractRoot, _templateDirName, id);
        Directory(destination).createSync(recursive: true);
        embeddedPath = p.join(destination, p.basename(fileName));
        File(
          embeddedPath,
        ).writeAsBytesSync(entry.content as List<int>, flush: true);
      }
      final assignments = <Map<String, dynamic>>[
        for (final item in (raw['assignments'] as List?) ?? const <Object?>[])
          if (item is Map) item.cast<String, dynamic>(),
      ];
      templates.add(
        _LoadedTemplate(
          id: id,
          fileName: fileName,
          embeddedPath: embeddedPath,
          assignments: assignments,
        ),
      );
      if (id == activeTemplateId) {
        embeddedTemplatePath = embeddedPath;
        // El mapeo de la plantilla activa es el que usa el proyecto.
        mappingAssignments
          ..clear()
          ..addAll(assignments);
      }
    }
  } else {
    embeddedTemplatePath = _extractSingleArtifactSync(
      archive: archive,
      dirPrefix: '$_templateDirName/',
      destinationDir: p.join(extractRoot, _templateDirName),
    );
  }
  final embeddedDatasourcePath = _extractSingleArtifactSync(
    archive: archive,
    dirPrefix: '$_datasourceDirName/',
    destinationDir: p.join(extractRoot, _datasourceDirName),
  );

  return _IsolateLoadResult(
    projectJson: projectJson,
    mappingAssignments: mappingAssignments,
    templates: templates,
    activeTemplateId: activeTemplateId,
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
