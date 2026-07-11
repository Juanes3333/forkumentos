import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/shared/data/pdf_document_repository.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_pdf_document_',
    );
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('carga texto seleccionable de un PDF mínimo', () async {
    final filePath = p.join(tempDirectory.path, 'plantilla.pdf');
    await _writeSimplePdf(filePath, 'Hola Forkumentos');

    final document = await const PdfDocumentRepository().load(filePath);

    expect(document.pages, isNotEmpty);
    final texts = document.pages
        .expand((page) => page.blocks)
        .whereType<DocumentParagraphBlock>()
        .expand((block) => block.paragraph.runs)
        .map((run) => run.text)
        .join('\n');
    expect(texts, contains('Hola Forkumentos'));
  });

  test('rechaza extensiones distintas a .pdf', () async {
    final filePath = p.join(tempDirectory.path, 'plantilla.docx');

    expect(
      () => const PdfDocumentRepository().load(filePath),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('.pdf'),
        ),
      ),
    );
  });
}

Future<void> _writeSimplePdf(String path, String text) async {
  final document = PdfDocument();
  document.pages.add().graphics.drawString(
    text,
    PdfStandardFont(PdfFontFamily.helvetica, 12),
    bounds: const Rect.fromLTWH(40, 40, 400, 40),
  );
  final bytes = Uint8List.fromList(await document.save());
  document.dispose();
  await File(path).writeAsBytes(bytes);
}
