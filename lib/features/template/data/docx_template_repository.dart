import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:forkumentos/features/template/domain/template.dart';
import 'package:forkumentos/features/template/domain/template_repository.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

const _invalidDocxMessage = 'El archivo no es un documento DOCX válido.';

final class DocxTemplateRepository implements TemplateRepository {
  const DocxTemplateRepository();

  @override
  Future<Template> load(String filePath) async {
    final normalizedExtension = p.extension(filePath).toLowerCase();
    if (normalizedExtension != '.docx') {
      throw const FormatException('Selecciona un archivo con extensión .docx.');
    }

    final bytes = await File(filePath).readAsBytes();

    final metadata = await compute<Map<String, Object?>, Map<String, Object?>>(
      _parseDocxContent,
      <String, Object?>{'bytes': bytes},
    );

    return Template(
      sourcePath: filePath,
      fileName: p.basename(filePath),
      fileSizeBytes: bytes.lengthInBytes,
      importedAt: DateTime.now().toUtc(),
      title: metadata['title'] as String?,
      author: metadata['author'] as String?,
      pageCount: metadata['pageCount'] as int?,
      wordCount: metadata['wordCount'] as int?,
    );
  }
}

Map<String, Object?> _parseDocxContent(Map<String, Object?> payload) {
  final bytes = payload['bytes'];
  if (bytes is! Uint8List) {
    throw const FormatException(_invalidDocxMessage);
  }

  final archive = _decodeArchive(bytes);
  final archiveEntries = _indexArchiveEntries(archive);

  _requireEntry(
    archiveEntries,
    requiredPath: '[Content_Types].xml',
    message: 'El DOCX no contiene [Content_Types].xml.',
  );
  _requireEntry(
    archiveEntries,
    requiredPath: 'word/document.xml',
    message: 'El DOCX no contiene word/document.xml.',
  );

  String? title;
  String? author;
  int? pageCount;
  int? wordCount;

  final coreEntry = archiveEntries['docprops/core.xml'];
  if (coreEntry != null) {
    try {
      final coreXml = XmlDocument.parse(_archiveEntryAsString(coreEntry));
      title = _findElementText(coreXml, localName: 'title');
      author = _findElementText(coreXml, localName: 'creator');
    } catch (_) {
      // Metadato opcional: cualquier error se ignora.
    }
  }

  final appEntry = archiveEntries['docprops/app.xml'];
  if (appEntry != null) {
    try {
      final appXml = XmlDocument.parse(_archiveEntryAsString(appEntry));
      pageCount = _findElementInt(appXml, localName: 'Pages');
      wordCount = _findElementInt(appXml, localName: 'Words');
    } catch (_) {
      // Metadato opcional: cualquier error se ignora.
    }
  }

  return <String, Object?>{
    'title': title,
    'author': author,
    'pageCount': pageCount,
    'wordCount': wordCount,
  };
}

Archive _decodeArchive(Uint8List bytes) {
  if (!_looksLikeZip(bytes)) {
    throw const FormatException(_invalidDocxMessage);
  }

  try {
    return ZipDecoder().decodeBytes(bytes, verify: true);
  } catch (_) {
    throw const FormatException(_invalidDocxMessage);
  }
}

bool _looksLikeZip(Uint8List bytes) {
  if (bytes.length < 4) {
    return false;
  }

  return bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
      (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08);
}

Map<String, ArchiveFile> _indexArchiveEntries(Archive archive) {
  return <String, ArchiveFile>{
    for (final file in archive.files) file.name.toLowerCase(): file,
  };
}

void _requireEntry(
  Map<String, ArchiveFile> entries, {
  required String requiredPath,
  required String message,
}) {
  if (!entries.containsKey(requiredPath.toLowerCase())) {
    throw FormatException(message);
  }
}

String _archiveEntryAsString(ArchiveFile file) {
  return utf8.decode(file.content, allowMalformed: true);
}

String? _findElementText(XmlDocument xml, {required String localName}) {
  for (final element in xml.descendants.whereType<XmlElement>()) {
    if (element.name.local != localName) {
      continue;
    }

    final text = element.innerText.trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  return null;
}

int? _findElementInt(XmlDocument xml, {required String localName}) {
  final rawValue = _findElementText(xml, localName: localName);
  if (rawValue == null) {
    return null;
  }

  return int.tryParse(rawValue);
}
