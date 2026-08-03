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

  test('con w:lastRenderedPageBreak la paginación sigue los marcadores y NO '
      'la heurística de relleno', () async {
    final filePath = p.join(tempDirectory.path, 'marcadores_ganan.docx');
    // Mismo volumen de texto que el caso heurístico (50 párrafos de 600
    // caracteres, que la estimación repartiría en varias páginas), pero con
    // un único marcador de Word en medio: Word dijo que solo hay 2 páginas.
    final body = <String>[
      for (var index = 0; index < 50; index++)
        _longParagraphXml(startsPage: index == 25),
    ].join('\n');
    await File(
      filePath,
    ).writeAsBytes(_buildDocxBytes(documentXml: _documentWithBody(body)));

    final document = await repository.load(filePath);

    expect(document.pages, hasLength(2));
    expect(_textParagraphCount(document.pages[0]), 25);
    expect(_textParagraphCount(document.pages[1]), 25);
  });

  test('un w:lastRenderedPageBreak apaga la heurística también para los '
      'tramos sin marcador', () async {
    final filePath = p.join(tempDirectory.path, 'marcador_unico.docx');
    // El marcador está al inicio: todo el texto posterior excede de sobra la
    // altura estimada de una página, pero sin más marcadores Word lo dejó en
    // una sola, así que la segunda página no se vuelve a partir.
    final body = <String>[
      '<w:p><w:r><w:t>Portada</w:t></w:r></w:p>',
      for (var index = 0; index < 40; index++)
        _longParagraphXml(startsPage: index == 0),
    ].join('\n');
    await File(
      filePath,
    ).writeAsBytes(_buildDocxBytes(documentXml: _documentWithBody(body)));

    final document = await repository.load(filePath);

    expect(document.pages, hasLength(2));
    expect(_paragraphs(document.pages[0]).first.runs.single.text, 'Portada');
    expect(_textParagraphCount(document.pages[0]), 1);
    expect(_textParagraphCount(document.pages[1]), 40);
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

  test(
    'conserva el texto de un run envuelto en w:ins (cambio aceptado)',
    () async {
      final filePath = p.join(tempDirectory.path, 'insertado.docx');
      await File(filePath).writeAsBytes(
        _buildDocxBytes(
          documentXml: _documentWithBody('''
<w:p>
  <w:r><w:t>Antes </w:t></w:r>
  <w:ins>
    <w:r><w:t>insertado</w:t></w:r>
  </w:ins>
  <w:r><w:t> después</w:t></w:r>
</w:p>
'''),
        ),
      );

      final document = await repository.load(filePath);

      expect(
        _paragraphs(document.pages.single).single.runs.map((run) => run.text),
        <String>['Antes ', 'insertado', ' después'],
      );
    },
  );

  test('descarta el texto de un run envuelto en w:del', () async {
    final filePath = p.join(tempDirectory.path, 'eliminado.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r><w:t>Antes </w:t></w:r>
  <w:del>
    <w:r><w:delText>eliminado</w:delText></w:r>
  </w:del>
  <w:r><w:t> después</w:t></w:r>
</w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(
      _paragraphs(document.pages.single).single.runs.map((run) => run.text),
      <String>['Antes ', ' después'],
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

  test('w:drawing sin relación resoluble agrega omisión image', () async {
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

  test('w:drawing extrae los bytes y el tamaño de la imagen del cuerpo '
      'sin marcarla como omitida', () async {
    final filePath = p.join(tempDirectory.path, 'imagen_cuerpo.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r><w:t>Antes</w:t></w:r>
  <w:r>$_inlineDrawingXml</w:r>
  <w:r><w:t>Después</w:t></w:r>
</w:p>
'''),
        extraEntries: <String, String>{
          'word/_rels/document.xml.rels': _imageRelationshipsXml,
        },
        binaryEntries: <String, List<int>>{'word/media/image1.png': _pngBytes},
      ),
    );

    final document = await repository.load(filePath);

    expect(document.omissions.contains(DocumentOmission.image), isFalse);
    final runs = _paragraphs(document.pages.single).single.runs;
    expect(runs.map((run) => run.text).toList(), <String>[
      'Antes',
      '',
      'Después',
    ]);

    final image = runs[1].image;
    expect(image, isNotNull);
    expect(image!.bytes, orderedEquals(_pngBytes));
    // 914400 EMU = 1 pulgada = 72 puntos; 457200 EMU = media pulgada.
    expect(image.widthPoints, closeTo(72, 0.001));
    expect(image.heightPoints, closeTo(36, 0.001));
  });

  test('una imagen del encabezado se resuelve por el .rels de su propia '
      'parte', () async {
    final filePath = p.join(tempDirectory.path, 'imagen_encabezado.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: '''
<w:document
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    <w:p><w:r><w:t>Cuerpo</w:t></w:r></w:p>
    <w:sectPr><w:headerReference w:type="default" r:id="rId9" /></w:sectPr>
  </w:body>
</w:document>
''',
        extraEntries: <String, String>{
          'word/header1.xml':
              '''
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:r><w:t>ACME</w:t></w:r>
    <w:r>$_inlineDrawingXml</w:r>
  </w:p>
</w:hdr>
''',
          'word/_rels/document.xml.rels': '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId9" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml" />
</Relationships>
''',
          'word/_rels/header1.xml.rels': _imageRelationshipsXml,
        },
        binaryEntries: <String, List<int>>{'word/media/image1.png': _pngBytes},
      ),
    );

    final document = await repository.load(filePath);

    expect(document.omissions.contains(DocumentOmission.image), isFalse);
    final headerRuns =
        (document.header.single as DocumentParagraphBlock).paragraph.runs;
    expect(headerRuns.first.text, 'ACME');
    expect(headerRuns.last.image?.bytes, orderedEquals(_pngBytes));
  });

  test('w:pict de VML resuelve la imagen y su tamaño desde el estilo '
      'de la forma', () async {
    final filePath = p.join(tempDirectory.path, 'imagen_vml.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r>
    <w:pict xmlns:v="urn:schemas-microsoft-com:vml"
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <v:shape style="width:54pt;height:18pt">
        <v:imagedata r:id="rId5" />
      </v:shape>
    </w:pict>
  </w:r>
</w:p>
'''),
        extraEntries: <String, String>{
          'word/_rels/document.xml.rels': '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png" />
</Relationships>
''',
        },
        binaryEntries: <String, List<int>>{'word/media/image1.png': _pngBytes},
      ),
    );

    final document = await repository.load(filePath);

    final image = _paragraphs(document.pages.single).single.runs.single.image;
    expect(image?.widthPoints, closeTo(54, 0.001));
    expect(image?.heightPoints, closeTo(18, 0.001));
  });

  test('mc:Fallback no duplica la imagen ni el texto de mc:Choice', () async {
    final filePath = p.join(tempDirectory.path, 'alternate_content.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r>
    <mc:AlternateContent
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">
      <mc:Choice Requires="wps">$_inlineDrawingXml</mc:Choice>
      <mc:Fallback>
        <w:pict xmlns:v="urn:schemas-microsoft-com:vml"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <v:shape style="width:72pt;height:36pt">
            <v:imagedata r:id="rId5" />
            <v:textbox><w:txbxContent><w:p><w:r><w:t>Copia</w:t></w:r></w:p></w:txbxContent></v:textbox>
          </v:shape>
        </w:pict>
      </mc:Fallback>
    </mc:AlternateContent>
  </w:r>
</w:p>
'''),
        extraEntries: <String, String>{
          'word/_rels/document.xml.rels': _imageRelationshipsXml,
        },
        binaryEntries: <String, List<int>>{'word/media/image1.png': _pngBytes},
      ),
    );

    final document = await repository.load(filePath);

    final runs = _paragraphs(document.pages.single).single.runs;
    expect(runs.where((run) => run.image != null), hasLength(1));
    expect(runs.map((run) => run.text).join(), isEmpty);
  });

  test('el texto de un cuadro de texto no se mezcla con el del párrafo '
      'que lo contiene', () async {
    final filePath = p.join(tempDirectory.path, 'cuadro_texto.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:r><w:t>Visible</w:t></w:r>
  <w:r>
    <w:drawing xmlns:wp="urn:test">
      <wp:inline>
        <wp:extent cx="914400" cy="457200" />
        <w:txbxContent><w:p><w:r><w:t>Dentro del cuadro</w:t></w:r></w:p></w:txbxContent>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    expect(
      _paragraphs(document.pages.single).single.runs.map((run) => run.text),
      <String>['Visible'],
    );
  });

  test('w:jc, w:ind y w:spacing directos del párrafo se exponen en el '
      'modelo', () async {
    final filePath = p.join(tempDirectory.path, 'formato_parrafo.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:pPr>
    <w:jc w:val="center" />
    <w:ind w:left="720" w:right="360" w:firstLine="240" />
    <w:spacing w:before="120" w:after="240" w:line="276" w:lineRule="auto" />
  </w:pPr>
  <w:r><w:t>Centrado</w:t></w:r>
</w:p>
<w:p>
  <w:pPr>
    <w:jc w:val="both" />
    <w:ind w:left="720" w:hanging="360" />
    <w:spacing w:line="360" w:lineRule="exact" />
  </w:pPr>
  <w:r><w:t>Justificado</w:t></w:r>
</w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    final paragraphs = _paragraphs(document.pages.single);
    expect(paragraphs[0].alignment, DocumentAlignment.center);
    expect(paragraphs[0].indentLeftPoints, 36);
    expect(paragraphs[0].indentRightPoints, 18);
    expect(paragraphs[0].indentFirstLinePoints, 12);
    expect(paragraphs[0].spacingBeforePoints, 6);
    expect(paragraphs[0].spacingAfterPoints, 12);
    expect(paragraphs[0].lineSpacingMultiple, closeTo(1.15, 0.0001));
    expect(paragraphs[0].lineSpacingExactPoints, isNull);

    expect(paragraphs[1].alignment, DocumentAlignment.justify);
    expect(paragraphs[1].indentFirstLinePoints, -18);
    expect(paragraphs[1].lineSpacingExactPoints, 18);
    expect(paragraphs[1].lineSpacingMultiple, isNull);
  });

  test('w:rFonts resuelve la fuente del tema y el formato directo gana '
      'sobre el estilo', () async {
    final filePath = p.join(tempDirectory.path, 'fuentes.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p><w:r><w:t>Cuerpo</w:t></w:r></w:p>
<w:p>
  <w:pPr><w:pStyle w:val="Titulo" /></w:pPr>
  <w:r><w:t>Título</w:t></w:r>
</w:p>
<w:p>
  <w:r>
    <w:rPr><w:rFonts w:ascii="Courier New" /></w:rPr>
    <w:t>Monoespaciada</w:t>
  </w:r>
</w:p>
'''),
        extraEntries: <String, String>{
          'word/theme/theme1.xml': _themeXml,
          'word/styles.xml': _themedStylesXml,
        },
      ),
    );

    final document = await repository.load(filePath);

    final paragraphs = _paragraphs(document.pages.single);
    expect(paragraphs[0].runs.single.fontFamily, 'Cambria');
    expect(paragraphs[0].runs.single.fontSizePoints, 11);
    expect(paragraphs[1].runs.single.fontFamily, 'Calibri');
    expect(paragraphs[1].runs.single.fontSizePoints, 14);
    expect(paragraphs[2].runs.single.fontFamily, 'Courier New');
  });

  test('w:contextualSpacing suprime el espacio entre párrafos del mismo '
      'estilo', () async {
    final filePath = p.join(tempDirectory.path, 'contextual.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p>
  <w:pPr><w:pStyle w:val="Lista" /></w:pPr>
  <w:r><w:t>Uno</w:t></w:r>
</w:p>
<w:p>
  <w:pPr><w:pStyle w:val="Lista" /></w:pPr>
  <w:r><w:t>Dos</w:t></w:r>
</w:p>
<w:p><w:r><w:t>Otro estilo</w:t></w:r></w:p>
'''),
        extraEntries: <String, String>{
          'word/styles.xml': '''
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="Lista">
    <w:pPr>
      <w:spacing w:before="200" w:after="200" />
      <w:contextualSpacing />
    </w:pPr>
  </w:style>
</w:styles>
''',
        },
      ),
    );

    final document = await repository.load(filePath);

    final paragraphs = _paragraphs(document.pages.single);
    // Entre "Uno" y "Dos" (mismo estilo) no hay espacio; contra el párrafo
    // siguiente, de otro estilo, sí se conserva.
    expect(paragraphs[0].spacingBeforePoints, 10);
    expect(paragraphs[0].spacingAfterPoints, 0);
    expect(paragraphs[1].spacingBeforePoints, 0);
    expect(paragraphs[1].spacingAfterPoints, 10);
  });

  test('contextualSpacing por docDefaults no suprime el primer/último párrafo '
      'del body (no hay sibling previo/siguiente)', () async {
    final filePath = p.join(tempDirectory.path, 'contextual_bordes.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:p><w:r><w:t>Uno</w:t></w:r></w:p>
<w:p><w:r><w:t>Dos</w:t></w:r></w:p>
<w:p><w:r><w:t>Tres</w:t></w:r></w:p>
'''),
        extraEntries: <String, String>{
          'word/styles.xml': '''
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:before="200" w:after="200" />
        <w:contextualSpacing />
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
</w:styles>
''',
        },
      ),
    );

    final document = await repository.load(filePath);

    final paragraphs = _paragraphs(document.pages.single);
    // Ninguno de los tres párrafos tiene w:pStyle, así que los tres
    // comparten styleId == null. Antes del fix, `null == null` suprimía
    // por error el spacing inicial del primero y el final del último por
    // no distinguir "sin sibling" de "sibling sin estilo explícito".
    expect(paragraphs[0].spacingBeforePoints, 10);
    expect(paragraphs[0].spacingAfterPoints, 0);
    expect(paragraphs[1].spacingBeforePoints, 0);
    expect(paragraphs[1].spacingAfterPoints, 0);
    expect(paragraphs[2].spacingBeforePoints, 0);
    expect(paragraphs[2].spacingAfterPoints, 10);
  });

  test('contextualSpacing por docDefaults no suprime el primer/último párrafo '
      'de una celda de tabla', () async {
    final filePath = p.join(tempDirectory.path, 'contextual_celda.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:tbl>
  <w:tblGrid><w:gridCol w:w="4320" /></w:tblGrid>
  <w:tr>
    <w:tc>
      <w:p><w:r><w:t>Uno</w:t></w:r></w:p>
      <w:p><w:r><w:t>Dos</w:t></w:r></w:p>
    </w:tc>
  </w:tr>
</w:tbl>
'''),
        extraEntries: <String, String>{
          'word/styles.xml': '''
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:before="200" w:after="200" />
        <w:contextualSpacing />
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
</w:styles>
''',
        },
      ),
    );

    final document = await repository.load(filePath);

    final table =
        (document.pages.single.blocks.single as DocumentTableBlock).table;
    final cellParagraphs = <DocumentParagraph>[
      for (final block in table.rows.single.cells.single.blocks)
        if (block case DocumentParagraphBlock(:final paragraph)) paragraph,
    ];
    expect(cellParagraphs[0].spacingBeforePoints, 10);
    expect(cellParagraphs[0].spacingAfterPoints, 0);
    expect(cellParagraphs[1].spacingBeforePoints, 0);
    expect(cellParagraphs[1].spacingAfterPoints, 10);
  });

  test('pgMar expone las distancias de encabezado y pie', () async {
    final filePath = p.join(tempDirectory.path, 'margenes.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: '''
<w:document
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Cuerpo</w:t></w:r></w:p>
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840" />
      <w:pgMar w:top="1440" w:right="1800" w:bottom="1440" w:left="1800"
          w:header="720" w:footer="576" />
    </w:sectPr>
  </w:body>
</w:document>
''',
      ),
    );

    final document = await repository.load(filePath);

    final margins = document.pages.single.margins;
    expect(margins.topPoints, 72);
    expect(margins.leftPoints, 90);
    expect(margins.headerDistancePoints, 36);
    expect(margins.footerDistancePoints, 28.8);
  });

  test('la tabla expone su retícula y no inventa bordes que Word no '
      'dibuja', () async {
    final filePath = p.join(tempDirectory.path, 'tabla_sin_bordes.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:tbl>
  <w:tblPr><w:jc w:val="center" /></w:tblPr>
  <w:tblGrid><w:gridCol w:w="4320" /><w:gridCol w:w="2160" /></w:tblGrid>
  <w:tr>
    <w:tc>
      <w:tcPr><w:tcW w:w="4320" w:type="dxa" /></w:tcPr>
      <w:p><w:r><w:t>Campo</w:t></w:r></w:p>
    </w:tc>
    <w:tc><w:p><w:r><w:t>Valor</w:t></w:r></w:p></w:tc>
  </w:tr>
</w:tbl>
'''),
      ),
    );

    final document = await repository.load(filePath);

    final table =
        (document.pages.single.blocks.single as DocumentTableBlock).table;
    expect(table.columnWidthsPoints, <double>[216, 108]);
    expect(table.alignment, DocumentAlignment.center);
    expect(table.borderWidthPoints, 0);
    expect(table.rows.single.cells.first.widthPoints, 216);
    expect(table.rows.single.cells.last.widthPoints, isNull);
  });

  test('w:tblBorders declara el grosor y el color del borde', () async {
    final filePath = p.join(tempDirectory.path, 'tabla_con_bordes.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:tbl>
  <w:tblPr>
    <w:tblBorders>
      <w:top w:val="single" w:sz="12" w:color="FF0000" />
      <w:bottom w:val="single" w:sz="12" w:color="FF0000" />
    </w:tblBorders>
  </w:tblPr>
  <w:tr><w:tc><w:p><w:r><w:t>Celda</w:t></w:r></w:p></w:tc></w:tr>
</w:tbl>
'''),
      ),
    );

    final document = await repository.load(filePath);

    final table =
        (document.pages.single.blocks.single as DocumentTableBlock).table;
    // w:sz está en octavos de punto: 12 -> 1.5pt.
    expect(table.borderWidthPoints, 1.5);
    expect(table.borderColorHex, 'FF0000');
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

  test('un w:lastRenderedPageBreak dentro de una tabla no genera una página '
      'en blanco a continuación', () async {
    final filePath = p.join(tempDirectory.path, 'tabla_partida.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:tbl>
  <w:tr><w:tc><w:p><w:r><w:t>Fila 1</w:t></w:r></w:p></w:tc></w:tr>
  <w:tr>
    <w:tc>
      <w:p><w:r><w:lastRenderedPageBreak /><w:t>Fila 2</w:t></w:r></w:p>
    </w:tc>
  </w:tr>
</w:tbl>
<w:p><w:r><w:t>Después</w:t></w:r></w:p>
'''),
      ),
    );

    final document = await repository.load(filePath);

    // La tabla es atómica: cabe entera en la página actual y el párrafo
    // siguiente la acompaña. Ninguna página queda vacía.
    expect(document.pages, hasLength(1));
    expect(_paragraphs(document.pages[0]).single.runs.single.text, 'Después');
  });

  test('una celda con w:lastRenderedPageBreak conserva el párrafo entero en '
      'un solo bloque', () async {
    final filePath = p.join(tempDirectory.path, 'celda_marcador.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:tbl>
  <w:tr>
    <w:tc>
      <w:p>
        <w:r><w:t>Antes</w:t><w:lastRenderedPageBreak /><w:t>Después</w:t></w:r>
      </w:p>
    </w:tc>
  </w:tr>
</w:tbl>
'''),
      ),
    );

    final document = await repository.load(filePath);

    final block = document.pages[0].blocks.single;
    final table = (block as DocumentTableBlock).table;
    final cellBlocks = table.rows.single.cells.single.blocks;
    // Un solo bloque: el marcador no trocea el párrafo de la celda. Si lo
    // troceara, los índices de bloque de celda dejarían de coincidir con los
    // que docx_zip_exporter.dart recorre al exportar.
    expect(cellBlocks, hasLength(1));
    final paragraph = (cellBlocks.single as DocumentParagraphBlock).paragraph;
    expect(paragraph.runs.map((run) => run.text).join(), 'AntesDespués');
  });

  test('un documento cuyos únicos marcadores están dentro de tablas mantiene '
      'la heurística de relleno activa', () async {
    final filePath = p.join(tempDirectory.path, 'marcador_solo_tabla.docx');
    await File(filePath).writeAsBytes(
      _buildDocxBytes(
        documentXml: _documentWithBody('''
<w:tbl>
  <w:tr>
    <w:tc>
      <w:p><w:r><w:lastRenderedPageBreak /><w:t>Celda</w:t></w:r></w:p>
    </w:tc>
  </w:tr>
</w:tbl>
${List<String>.filled(40, _longParagraphXml(startsPage: false)).join()}
'''),
      ),
    );

    final document = await repository.load(filePath);

    // El marcador de la tabla se ignora por completo, así que NO cuenta como
    // "Word ya maquetó esto": sin ninguna señal explícita utilizable el
    // relleno heurístico debe seguir repartiendo el texto largo.
    expect(document.pages.length, greaterThan(1));
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

// Párrafo de 600 caracteres — el mismo volumen que usa el caso heurístico —
// opcionalmente precedido del marcador con el que Word abre una página nueva.
String _longParagraphXml({required bool startsPage}) {
  final marker = startsPage ? '<w:lastRenderedPageBreak />' : '';
  return '<w:p><w:r>$marker<w:t>${'A' * 600}</w:t></w:r></w:p>';
}

// Un `w:lastRenderedPageBreak` al inicio de un run deja un chunk vacío antes
// del corte (el párrafo que abre la página nueva). Contar solo los párrafos
// CON texto expresa el reparto real sin depender de ese detalle.
int _textParagraphCount(DocumentPage page) {
  return _paragraphs(
    page,
  ).where((paragraph) => paragraph.runs.isNotEmpty).length;
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

// Un PNG válido de 1x1: los bytes tienen que decodificar de verdad para que
// el visor pueda pintarlos, así que no sirve un relleno arbitrario.
const _pngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99,
  0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

// 914400 EMU = 1 pulgada = 72 puntos.
const _inlineDrawingXml = '''
<w:drawing xmlns:wp="urn:test"
    xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <wp:inline>
    <wp:extent cx="914400" cy="457200" />
    <a:graphic><a:graphicData><a:blip r:embed="rId5" /></a:graphicData></a:graphic>
  </wp:inline>
</w:drawing>
''';

const _imageRelationshipsXml = '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png" />
</Relationships>
''';

const _themeXml = '''
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <a:themeElements>
    <a:fontScheme name="Office">
      <a:majorFont><a:latin typeface="Calibri" /></a:majorFont>
      <a:minorFont><a:latin typeface="Cambria" /></a:minorFont>
    </a:fontScheme>
  </a:themeElements>
</a:theme>
''';

const _themedStylesXml = '''
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr><w:rFonts w:asciiTheme="minorHAnsi" /><w:sz w:val="22" /></w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:styleId="Titulo">
    <w:rPr><w:rFonts w:asciiTheme="majorHAnsi" /><w:sz w:val="28" /></w:rPr>
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
  Map<String, List<int>> binaryEntries = const <String, List<int>>{},
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

  for (final entry in binaryEntries.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }

  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('No se pudo codificar el ZIP DOCX de prueba.');
  }

  return Uint8List.fromList(encoded);
}
