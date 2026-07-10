import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/shared/data/docx_document_repository.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late DocxDocumentRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_document_viewer_repo_test_',
    );
    repository = const DocxDocumentRepository();
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('parsea párrafos/runs con bold, italic y underline', () async {
    final filePath = p.join(tempDirectory.path, 'formato.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r><w:rPr><w:b /></w:rPr><w:t>Negrita</w:t></w:r>
  <w:r><w:rPr><w:i /></w:rPr><w:t>Cursiva</w:t></w:r>
  <w:r><w:rPr><w:u w:val="single" /></w:rPr><w:t>Subrayada</w:t></w:r>
</w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(document.pages, hasLength(1));
    final runs = _paragraphs(document.pages.single).single.runs;
    expect(runs, hasLength(3));
    expect(
      runs[0],
      const DocumentRun(
        text: 'Negrita',
        isBold: true,
        isItalic: false,
        isUnderlined: false,
      ),
    );
    expect(
      runs[1],
      const DocumentRun(
        text: 'Cursiva',
        isBold: false,
        isItalic: true,
        isUnderlined: false,
      ),
    );
    expect(
      runs[2],
      const DocumentRun(
        text: 'Subrayada',
        isBold: false,
        isItalic: false,
        isUnderlined: true,
      ),
    );
  });

  test('w:br type=page divide el contenido en páginas correctas', () async {
    final filePath = p.join(tempDirectory.path, 'saltos.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r><w:t>Antes</w:t></w:r>
  <w:r><w:br w:type="page" /></w:r>
  <w:r><w:t>Después</w:t></w:r>
</w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(document.pages, hasLength(2));
    expect(_paragraphs(document.pages[0]), hasLength(1));
    expect(_paragraphs(document.pages[0]).single.runs.single.text, 'Antes');
    expect(_paragraphs(document.pages[1]), hasLength(1));
    expect(_paragraphs(document.pages[1]).single.runs.single.text, 'Después');
  });

  test('salto de página final no genera una página fantasma vacía', () async {
    final filePath = p.join(tempDirectory.path, 'salto_final.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r><w:t>Antes</w:t></w:r>
  <w:r><w:t>Después</w:t></w:r>
  <w:r><w:br w:type="page" /></w:r>
</w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(document.pages, hasLength(1));
    final runs = _paragraphs(document.pages[0]).single.runs;
    expect(runs.map((run) => run.text), <String>['Antes', 'Después']);
  });

  test('sin saltos explícitos produce una sola página', () async {
    final filePath = p.join(tempDirectory.path, 'una_pagina.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody(
          '<w:p><w:r><w:t>Contenido único</w:t></w:r></w:p>',
        ),
      ),
    );

    final document = await repository.load(filePath);

    expect(document.pages, hasLength(1));
  });

  test('preserva párrafo vacío como runs vacíos', () async {
    final filePath = p.join(tempDirectory.path, 'parrafo_vacio.docx');
    await File(
      filePath,
    ).writeAsBytes(_buildDocxBytes(documentXml: _documentWithBody('<w:p />')));

    final document = await repository.load(filePath);

    expect(_paragraphs(document.pages.single), hasLength(1));
    expect(_paragraphs(document.pages.single).single.runs, isEmpty);
  });

  test('excluye texto oculto por w:vanish', () async {
    final filePath = p.join(tempDirectory.path, 'oculto.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r>
    <w:rPr><w:vanish /></w:rPr>
    <w:t>Oculto</w:t>
  </w:r>
  <w:r><w:t>Visible</w:t></w:r>
</w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(_paragraphs(document.pages.single).single.runs, hasLength(1));
    expect(
      _paragraphs(document.pages.single).single.runs.single.text,
      'Visible',
    );
  });

  test('w:tbl parsea contenido de tabla como bloque', () async {
    final filePath = p.join(tempDirectory.path, 'tabla.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:tbl>
  <w:tr><w:tc><w:p><w:r><w:t>TablaOculta</w:t></w:r></w:p></w:tc></w:tr>
</w:tbl>
<w:p><w:r><w:t>Visible</w:t></w:r></w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(document.pages.single.blocks, hasLength(2));
    expect(document.pages.single.blocks.first, isA<DocumentTableBlock>());
    expect(document.pages.single.blocks.last, isA<DocumentParagraphBlock>());
    expect(
      _paragraphs(document.pages.single).single.runs.single.text,
      'Visible',
    );
  });

  test('run con w:drawing agrega omisión image', () async {
    final filePath = p.join(tempDirectory.path, 'imagen.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r>
    <w:t>Texto</w:t>
    <w:drawing><wp:inline xmlns:wp="urn:test" /></w:drawing>
  </w:r>
</w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(document.omissions.contains(DocumentOmission.image), isTrue);
  });

  test('presencia de header/footer y footnotes agrega omisiones', () async {
    final filePath = p.join(tempDirectory.path, 'omisiones_estructura.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('<w:p><w:r><w:t>Hola</w:t></w:r></w:p>'),
        extraEntries: <String, String>{
          'word/header1.xml': '<w:hdr xmlns:w="x"></w:hdr>',
          'word/footnotes.xml': '<w:footnotes xmlns:w="x"></w:footnotes>',
        },
      ),
    );

    final document = await repository.load(filePath);

    expect(document.omissions.contains(DocumentOmission.headerFooter), isTrue);
    expect(document.omissions.contains(DocumentOmission.footnote), isTrue);
  });

  test('convierte pgSz/pgMar de twentieths-of-point a points', () async {
    final filePath = p.join(tempDirectory.path, 'tamano_margenes.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p><w:r><w:t>Hola</w:t></w:r></w:p>
<w:sectPr>
  <w:pgSz w:w="12000" w:h="16000" />
  <w:pgMar w:top="1000" w:right="1200" w:bottom="1400" w:left="1600" />
</w:sectPr>
'''),
      ),
    );

    final page = (await repository.load(filePath)).pages.single;

    expect(page.widthPoints, 600);
    expect(page.heightPoints, 800);
    expect(page.margins.topPoints, 50);
    expect(page.margins.rightPoints, 60);
    expect(page.margins.bottomPoints, 70);
    expect(page.margins.leftPoints, 80);
  });

  test('sin sectPr usa defaults de carta US', () async {
    final filePath = p.join(tempDirectory.path, 'default_carta.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('<w:p><w:r><w:t>Hola</w:t></w:r></w:p>'),
      ),
    );

    final page = (await repository.load(filePath)).pages.single;

    expect(page.widthPoints, 612);
    expect(page.heightPoints, 792);
    expect(page.margins.topPoints, 72);
    expect(page.margins.rightPoints, 72);
    expect(page.margins.bottomPoints, 72);
    expect(page.margins.leftPoints, 72);
  });

  test('falla cuando falta word/document.xml', () async {
    final filePath = p.join(tempDirectory.path, 'sin_document_xml.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        includeWordDocumentXml: false,
        documentXml: _documentWithBody('<w:p />'),
      ),
    );

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

  test('rechaza extensión no DOCX antes de leer archivo', () async {
    final filePath = p.join(tempDirectory.path, 'no_docx.txt');

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
    await File(filePath).writeAsBytes(<int>[0, 1, 2, 3, 4, 5, 6]);

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
}

List<DocumentParagraph> _paragraphs(DocumentPage page) {
  return <DocumentParagraph>[
    for (final block in page.blocks)
      if (block case DocumentParagraphBlock(:final paragraph)) paragraph,
  ];
}

String _documentWithBody(String bodyContent) {
  return '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $bodyContent
  </w:body>
</w:document>
''';
}

Uint8List _buildDocxBytes({
  required String documentXml,
  bool includeContentTypesXml = true,
  bool includeWordDocumentXml = true,
  Map<String, String> extraEntries = const <String, String>{},
}) {
  final archive = Archive();

  if (includeContentTypesXml) {
    archive.addFile(ArchiveFile.string('[Content_Types].xml', '<Types />'));
  }

  if (includeWordDocumentXml) {
    archive.addFile(ArchiveFile.string('word/document.xml', documentXml));
  }

  for (final entry in extraEntries.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }

  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('No se pudo codificar el ZIP DOCX de prueba.');
  }

  return Uint8List.fromList(encoded);
}
