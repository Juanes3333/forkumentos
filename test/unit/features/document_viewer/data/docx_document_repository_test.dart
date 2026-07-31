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

  test(
    'w:lastRenderedPageBreak en un run separado divide el contenido',
    () async {
      final filePath = p.join(tempDirectory.path, 'lastrendered_run.docx');
      await File(filePath).writeAsBytes(
        _buildDocxBytes(
          documentXml: _documentWithBody('''
<w:p>
  <w:r><w:t>Antes</w:t></w:r>
  <w:r><w:lastRenderedPageBreak /></w:r>
  <w:r><w:t>Después</w:t></w:r>
</w:p>
'''),
        ),
      );

      final document = await repository.load(filePath);

      expect(document.pages, hasLength(2));
      expect(_paragraphs(document.pages[0]).single.runs.single.text, 'Antes');
      expect(_paragraphs(document.pages[1]).single.runs.single.text, 'Después');
    },
  );

  test(
    'w:lastRenderedPageBreak al inicio de un run con texto divide la página',
    () async {
      final filePath = p.join(tempDirectory.path, 'lastrendered_inicio.docx');
      await File(filePath).writeAsBytes(
        _buildDocxBytes(
          documentXml: _documentWithBody('''
<w:p>
  <w:r><w:lastRenderedPageBreak /><w:t>Después</w:t></w:r>
</w:p>
'''),
        ),
      );

      final document = await repository.load(filePath);

      expect(document.pages, hasLength(2));
      expect(_paragraphs(document.pages[1]).single.runs.single.text, 'Después');
    },
  );

  test('w:lastRenderedPageBreak en medio de un run divide el texto', () async {
    final filePath = p.join(tempDirectory.path, 'lastrendered_medio.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r><w:t>Antes</w:t><w:lastRenderedPageBreak /><w:t>Después</w:t></w:r>
</w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(document.pages, hasLength(2));
    expect(_paragraphs(document.pages[0]).single.runs.single.text, 'Antes');
    expect(_paragraphs(document.pages[1]).single.runs.single.text, 'Después');
  });

  test(
    'w:lastRenderedPageBreak al final de un run no genera página fantasma',
    () async {
      final filePath = p.join(tempDirectory.path, 'lastrendered_final.docx');
      await File(filePath).writeAsBytes(
        _buildDocxBytes(
          documentXml: _documentWithBody('''
<w:p>
  <w:r><w:t>Antes</w:t></w:r>
  <w:r><w:t>Después</w:t></w:r>
  <w:r><w:lastRenderedPageBreak /></w:r>
</w:p>
'''),
        ),
      );

      final document = await repository.load(filePath);

      expect(document.pages, hasLength(1));
      final runs = _paragraphs(document.pages[0]).single.runs;
      expect(runs.map((run) => run.text), <String>['Antes', 'Después']);
    },
  );

  test('run que solo contiene w:lastRenderedPageBreak sin texto no rompe el '
      'parseo', () async {
    final filePath = p.join(tempDirectory.path, 'lastrendered_solo.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r><w:lastRenderedPageBreak /></w:r>
</w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(document.pages, hasLength(1));
  });

  test(
    'w:pageBreakBefore en pPr divide el contenido en páginas correctas',
    () async {
      final filePath = p.join(tempDirectory.path, 'pagebreakbefore.docx');
      await File(filePath).writeAsBytes(
        _buildDocxBytes(
          documentXml: _documentWithBody('''
<w:p><w:r><w:t>Antes</w:t></w:r></w:p>
<w:p>
  <w:pPr><w:pageBreakBefore /></w:pPr>
  <w:r><w:t>Después</w:t></w:r>
</w:p>
'''),
        ),
      );

      final document = await repository.load(filePath);

      expect(document.pages, hasLength(2));
      expect(_paragraphs(document.pages[0]).single.runs.single.text, 'Antes');
      expect(_paragraphs(document.pages[1]).single.runs.single.text, 'Después');
    },
  );

  test(
    'w:pageBreakBefore en el primer párrafo no genera página vacía inicial',
    () async {
      final filePath = p.join(
        tempDirectory.path,
        'pagebreakbefore_primero.docx',
      );
      await File(filePath).writeAsBytes(
        _buildDocxBytes(
          documentXml: _documentWithBody('''
<w:p>
  <w:pPr><w:pageBreakBefore /></w:pPr>
  <w:r><w:t>Único</w:t></w:r>
</w:p>
'''),
        ),
      );

      final document = await repository.load(filePath);

      expect(document.pages, hasLength(1));
      expect(
        _paragraphs(document.pages.single).single.runs.single.text,
        'Único',
      );
    },
  );

  test('w:pageBreakBefore con w:val=false se ignora', () async {
    final filePath = p.join(tempDirectory.path, 'pagebreakbefore_false.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p><w:r><w:t>Antes</w:t></w:r></w:p>
<w:p>
  <w:pPr><w:pageBreakBefore w:val="false" /></w:pPr>
  <w:r><w:t>Después</w:t></w:r>
</w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(document.pages, hasLength(1));
    final paragraphs = _paragraphs(document.pages.single);
    expect(paragraphs, hasLength(2));
    expect(paragraphs[0].runs.single.text, 'Antes');
    expect(paragraphs[1].runs.single.text, 'Después');
  });

  test('sectPr embebido en pPr (fin de sección, w:type nextPage) divide la '
      'página', () async {
    final filePath = p.join(tempDirectory.path, 'seccion_nextpage.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p><w:r><w:t>Seccion1</w:t></w:r></w:p>
<w:p>
  <w:pPr>
    <w:sectPr><w:type w:val="nextPage" /></w:sectPr>
  </w:pPr>
</w:p>
<w:p><w:r><w:t>Seccion2</w:t></w:r></w:p>
<w:sectPr />
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(document.pages, hasLength(2));
    final page0Paragraphs = _paragraphs(document.pages[0]);
    expect(page0Paragraphs, hasLength(2));
    expect(page0Paragraphs[0].runs.single.text, 'Seccion1');
    expect(page0Paragraphs[1].runs, isEmpty);
    expect(_paragraphs(document.pages[1]).single.runs.single.text, 'Seccion2');
  });

  test('sectPr embebido en pPr sin w:type usa el default nextPage y divide la '
      'página', () async {
    final filePath = p.join(tempDirectory.path, 'seccion_default.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p><w:r><w:t>Seccion1</w:t></w:r></w:p>
<w:p>
  <w:pPr><w:sectPr /></w:pPr>
</w:p>
<w:p><w:r><w:t>Seccion2</w:t></w:r></w:p>
<w:sectPr />
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(document.pages, hasLength(2));
  });

  test(
    'sectPr embebido en pPr con w:type continuous NO divide la página',
    () async {
      final filePath = p.join(tempDirectory.path, 'seccion_continuous.docx');
      await File(filePath).writeAsBytes(
        _buildDocxBytes(
          documentXml: _documentWithBody('''
<w:p><w:r><w:t>Seccion1</w:t></w:r></w:p>
<w:p>
  <w:pPr>
    <w:sectPr><w:type w:val="continuous" /></w:sectPr>
  </w:pPr>
</w:p>
<w:p><w:r><w:t>Seccion2</w:t></w:r></w:p>
<w:sectPr />
'''),
        ),
      );

      final document = await repository.load(filePath);

      expect(document.pages, hasLength(1));
      final paragraphs = _paragraphs(document.pages.single);
      expect(paragraphs, hasLength(3));
      expect(paragraphs[0].runs.single.text, 'Seccion1');
      expect(paragraphs[1].runs, isEmpty);
      expect(paragraphs[2].runs.single.text, 'Seccion2');
    },
  );

  test('texto continuo largo sin marcadores explícitos se reparte en varias '
      'páginas por la heurística de relleno', () async {
    final filePath = p.join(tempDirectory.path, 'texto_largo.docx');
    // 600 caracteres por párrafo: con la calibración 11pt/1.15 (~85
    // caracteres/línea, ~51 líneas/página en tamaño carta) esto sigue
    // partiendo en varias páginas con margen amplio, a diferencia de un
    // párrafo corto que ahora cabría en una sola línea.
    final longParagraph = 'A' * 600;
    final body = List<String>.generate(
      50,
      (_) => '<w:p><w:r><w:t>$longParagraph</w:t></w:r></w:p>',
    ).join('\n');
    await File(
      filePath,
    ).writeAsBytes(_buildDocxBytes(documentXml: _documentWithBody(body)));

    final document = await repository.load(filePath);

    expect(document.pages.length, greaterThan(1));
    final totalParagraphs = document.pages.fold<int>(
      0,
      (sum, page) => sum + _paragraphs(page).length,
    );
    expect(totalParagraphs, 50);
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

  test('header/footer resolubles vía sectPr+rels se exponen y no agregan '
      'omisión', () async {
    final filePath = p.join(tempDirectory.path, 'header_footer_ok.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: '''
<w:document
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    <w:p><w:r><w:t>Cuerpo</w:t></w:r></w:p>
    <w:sectPr>
      <w:headerReference w:type="default" r:id="rId1" />
      <w:footerReference w:type="default" r:id="rId2" />
    </w:sectPr>
  </w:body>
</w:document>
''',
        extraEntries: <String, String>{
          'word/header1.xml': '''
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p><w:r><w:t>Encabezado</w:t></w:r></w:p>
</w:hdr>
''',
          'word/footer1.xml': '''
<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p><w:r><w:t>Pie</w:t></w:r></w:p>
</w:ftr>
''',
          'word/_rels/document.xml.rels': '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml" />
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml" />
</Relationships>
''',
        },
      ),
    );

    final document = await repository.load(filePath);

    expect(document.omissions.contains(DocumentOmission.headerFooter), isFalse);
    expect(
      (document.header.single as DocumentParagraphBlock)
          .paragraph
          .runs
          .single
          .text,
      'Encabezado',
    );
    expect(
      (document.footer.single as DocumentParagraphBlock)
          .paragraph
          .runs
          .single
          .text,
      'Pie',
    );
  });

  test('header presente en el ZIP sin sectPr/rels mantiene la omisión '
      'headerFooter', () async {
    final filePath = p.join(tempDirectory.path, 'header_footer_falla.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody(
          '<w:p><w:r><w:t>Cuerpo</w:t></w:r></w:p>',
        ),
        extraEntries: <String, String>{
          'word/header1.xml': '<w:hdr xmlns:w="x"></w:hdr>',
        },
      ),
    );

    final document = await repository.load(filePath);

    expect(document.omissions.contains(DocumentOmission.headerFooter), isTrue);
    expect(document.header, isEmpty);
    expect(document.footer, isEmpty);
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

  test(
    'párrafo con w:pStyle hereda color/negrita/tamaño/spacing del estilo con '
    'nombre',
    () async {
      final filePath = p.join(tempDirectory.path, 'estilo_heading.docx');
      await File(filePath).writeAsBytes(
        _buildDocxBytes(
          documentXml: _documentWithBody('''
<w:p>
  <w:pPr><w:pStyle w:val="Heading1" /></w:pPr>
  <w:r><w:t>Cláusula 1</w:t></w:r>
</w:p>
<w:p><w:r><w:t>Cuerpo normal</w:t></w:r></w:p>
'''),
          extraEntries: <String, String>{'word/styles.xml': _stylesXml},
        ),
      );

      final document = await repository.load(filePath);

      final paragraphs = _paragraphs(document.pages.single);
      final headingRun = paragraphs[0].runs.single;
      expect(headingRun.colorHex, '365F91');
      expect(headingRun.isBold, isTrue);
      expect(headingRun.fontSizePoints, 14);
      expect(paragraphs[0].spacingBeforePoints, 24);
      expect(paragraphs[0].spacingAfterPoints, 0);

      // Un párrafo sin pStyle no se ve afectado por el estilo con nombre.
      final normalRun = paragraphs[1].runs.single;
      expect(normalRun.colorHex, isNull);
      expect(normalRun.isBold, isFalse);
    },
  );

  test('propiedad inline en el run gana sobre el color heredado del estilo '
      'del párrafo', () async {
    final filePath = p.join(tempDirectory.path, 'estilo_override.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:pPr><w:pStyle w:val="Heading1" /></w:pPr>
  <w:r><w:rPr><w:color w:val="FF0000" /></w:rPr><w:t>Rojo inline</w:t></w:r>
</w:p>
'''),
        extraEntries: <String, String>{'word/styles.xml': _stylesXml},
      ),
    );

    final document = await repository.load(filePath);

    final run = _paragraphs(document.pages.single).single.runs.single;
    expect(run.colorHex, 'FF0000');
    // isBold no tiene override inline: sigue heredando del estilo.
    expect(run.isBold, isTrue);
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

// Inspirado en el word/styles.xml real de un DOCX generado por Word: Heading1
// basedOn Normal, con color/negrita/tamaño en w:rPr y spacing before en
// w:pPr. w:sz está en medios-puntos (28 -> 14pt); w:before/after en twips
// (480 -> 24pt).
const _stylesXml = '''
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:rPr><w:sz w:val="22" /></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:basedOn w:val="Normal" />
    <w:pPr><w:spacing w:before="480" w:after="0" /></w:pPr>
    <w:rPr>
      <w:b />
      <w:color w:val="365F91" />
      <w:sz w:val="28" />
    </w:rPr>
  </w:style>
</w:styles>
''';

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
