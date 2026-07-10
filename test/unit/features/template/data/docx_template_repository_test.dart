import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/template/data/docx_template_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late DocxTemplateRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_template_repo_test_',
    );
    repository = const DocxTemplateRepository();
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('carga DOCX válido mínimo con campos base', () async {
    final filePath = p.join(tempDirectory.path, 'plantilla_minima.docx');
    final bytes = _buildDocxBytes();
    await File(filePath).writeAsBytes(bytes);

    final template = await repository.load(filePath);

    expect(template.sourcePath, filePath);
    expect(template.fileName, 'plantilla_minima.docx');
    expect(template.fileSizeBytes, bytes.length);
    expect(template.importedAt.isUtc, isTrue);
    expect(template.title, isNull);
    expect(template.author, isNull);
    expect(template.pageCount, isNull);
    expect(template.wordCount, isNull);
  });

  test('falla cuando falta word/document.xml', () async {
    final filePath = p.join(tempDirectory.path, 'sin_document_xml.docx');
    await File(
      filePath,
    ).writeAsBytes(_buildDocxBytes(includeWordDocumentXml: false));

    expect(
      () => repository.load(filePath),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('word/document.xml'),
        ),
      ),
    );
  });

  test('falla cuando falta [Content_Types].xml', () async {
    final filePath = p.join(tempDirectory.path, 'sin_content_types.docx');
    await File(
      filePath,
    ).writeAsBytes(_buildDocxBytes(includeContentTypesXml: false));

    expect(
      () => repository.load(filePath),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('[Content_Types].xml'),
        ),
      ),
    );
  });

  test('rechaza extensión no DOCX sin leer archivo', () async {
    final filePath = p.join(tempDirectory.path, 'archivo_invalido.txt');

    expect(
      () => repository.load(filePath),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('.docx'),
        ),
      ),
    );
  });

  test('falla con bytes corruptos no ZIP', () async {
    final filePath = p.join(tempDirectory.path, 'corrupto.docx');
    await File(filePath).writeAsBytes(<int>[0, 1, 2, 3, 4, 5, 6, 7]);

    expect(
      () => repository.load(filePath),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'El archivo no es un documento DOCX válido.',
        ),
      ),
    );
  });

  test('extrae metadatos opcionales cuando existen', () async {
    final filePath = p.join(tempDirectory.path, 'con_metadatos.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        coreXml: '''
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title>Contrato base</dc:title>
  <dc:creator>Ana Pérez</dc:creator>
</cp:coreProperties>
''',
        appXml: '''
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
  <Pages>12</Pages>
  <Words>1800</Words>
</Properties>
''',
      ),
    );

    final template = await repository.load(filePath);

    expect(template.title, 'Contrato base');
    expect(template.author, 'Ana Pérez');
    expect(template.pageCount, 12);
    expect(template.wordCount, 1800);
  });

  test('metadatos opcionales ausentes quedan en null', () async {
    final filePath = p.join(tempDirectory.path, 'sin_metadatos.docx');
    await File(filePath).writeAsBytes(_buildDocxBytes());

    final template = await repository.load(filePath);

    expect(template.title, isNull);
    expect(template.author, isNull);
    expect(template.pageCount, isNull);
    expect(template.wordCount, isNull);
  });
}

Uint8List _buildDocxBytes({
  bool includeContentTypesXml = true,
  bool includeWordDocumentXml = true,
  String? coreXml,
  String? appXml,
}) {
  final archive = Archive();
  if (includeContentTypesXml) {
    archive.addFile(ArchiveFile.string('[Content_Types].xml', '<Types />'));
  }
  if (includeWordDocumentXml) {
    archive.addFile(
      ArchiveFile.string(
        'word/document.xml',
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" />',
      ),
    );
  }
  if (coreXml != null) {
    archive.addFile(ArchiveFile.string('docProps/core.xml', coreXml));
  }
  if (appXml != null) {
    archive.addFile(ArchiveFile.string('docProps/app.xml', appXml));
  }

  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}
