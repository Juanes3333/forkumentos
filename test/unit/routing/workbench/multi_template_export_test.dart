import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/export/domain/export_job.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:forkumentos/features/export/domain/export_progress.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';
import 'package:forkumentos/routing/workbench/export_launcher.dart';
import 'package:forkumentos/routing/workbench/multi_template_export.dart';
import 'package:path/path.dart' as p;

/// Fuera del `main`: el comando se copia a un isolate y el closure no puede
/// capturar el contexto del test.
Future<List<String?>> _row(int rowIndex) async => <String?>['Ana$rowIndex'];

void main() {
  late Directory destination;

  setUp(() async {
    destination = await Directory.systemTemp.createTemp(
      'forkumentos_multi_export_test_',
    );
  });

  tearDown(() async {
    await destination.delete(recursive: true);
  });

  const placeholders = <ExportPlaceholder>[
    ExportPlaceholder(
      steps: <ExportPathStep>[ExportPathStep.rootBlock(blockIndex: 0)],
      startOffset: 9,
      endOffset: 15,
      fieldIndex: 0,
    ),
  ];

  List<TemplateExportInput> twoTemplates({String second = 'Paz y salvo'}) =>
      <TemplateExportInput>[
        (
          name: 'Contrato',
          bytes: _docx('Estimado NOMBRE, firma el contrato.'),
          placeholders: placeholders,
        ),
        (
          name: second,
          bytes: _docx('Estimado NOMBRE, está a paz y salvo.'),
          placeholders: placeholders,
        ),
      ];

  ExportJob job({bool zip = false, List<int> rows = const <int>[0, 1]}) =>
      ExportJob(
        destinationFolder: destination.path,
        // Solo el campo: sin la subcarpeta, dos plantillas se pisarían.
        filenamePattern: const FilenamePattern(
          blocks: <FilenamePatternBlock>[
            FilenameFieldBlock(fieldIndex: 0, fieldHeader: 'nombre'),
          ],
        ),
        rangeMode: ExportRangeMode.custom,
        rowIndexes: rows,
        createZip: zip,
        templateBaseName: 'plantilla',
      );

  String documentXml(String path) {
    final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
    return utf8.decode(
      archive.findFile('word/document.xml')!.content as List<int>,
    );
  }

  test('cada plantilla escribe en su subcarpeta y no se pisan aunque el '
      'patrón sea solo el campo', () async {
    final result = await runTemplatesExport(
      session: ExportSession(),
      job: job(),
      templates: twoTemplates(),
      headers: const <String>['nombre'],
      resolveRow: _row,
      onProgress: (_) {},
    );

    expect(result.exportedCount, 4);
    expect(result.failedCount, 0);
    expect(result.cancelled, isFalse);
    final contrato = p.join(destination.path, 'Contrato');
    final paz = p.join(destination.path, 'Paz y salvo');
    for (final folder in <String>[contrato, paz]) {
      expect(
        Directory(folder).listSync().map((e) => p.basename(e.path)).toList()
          ..sort(),
        <String>['Ana0.docx', 'Ana1.docx'],
      );
    }
    expect(
      documentXml(p.join(contrato, 'Ana1.docx')),
      contains('Estimado Ana1, firma el contrato.'),
    );
    expect(
      documentXml(p.join(paz, 'Ana1.docx')),
      contains('Estimado Ana1, está a paz y salvo.'),
    );
  });

  test('el avance cuenta filas por plantillas', () async {
    final events = <ExportProgress>[];

    await runTemplatesExport(
      session: ExportSession(),
      job: job(),
      templates: twoTemplates(),
      headers: const <String>['nombre'],
      resolveRow: _row,
      onProgress: events.add,
    );

    expect(events.every((event) => event.total == 4), isTrue);
    expect(events.last.current, 4);
  });

  test('un solo ZIP con una carpeta por plantilla', () async {
    final result = await runTemplatesExport(
      session: ExportSession(),
      job: job(zip: true),
      templates: twoTemplates(),
      headers: const <String>['nombre'],
      resolveRow: _row,
      onProgress: (_) {},
    );

    expect(result.zipPath, isNotNull);
    final names =
        ZipDecoder()
            .decodeBytes(File(result.zipPath!).readAsBytesSync())
            .files
            .map((f) => f.name)
            .toList()
          ..sort();
    expect(names, <String>[
      'Contrato/Ana0.docx',
      'Contrato/Ana1.docx',
      'Paz y salvo/Ana0.docx',
      'Paz y salvo/Ana1.docx',
    ]);
  });

  test('dos plantillas con el mismo nombre usan carpetas distintas', () async {
    final result = await runTemplatesExport(
      session: ExportSession(),
      job: job(rows: const <int>[0]),
      templates: twoTemplates(second: 'contrato'),
      headers: const <String>['nombre'],
      resolveRow: _row,
      onProgress: (_) {},
    );

    expect(result.exportedCount, 2);
    expect(
      Directory(p.join(destination.path, 'Contrato')).existsSync(),
      isTrue,
    );
    expect(
      Directory(p.join(destination.path, 'contrato (2)')).existsSync(),
      isTrue,
    );
  });

  test('cancelar a mitad borra todo lo escrito y no deja carpetas', () async {
    final session = ExportSession();

    final result = await runTemplatesExport(
      session: session,
      job: job(),
      templates: twoTemplates(),
      headers: const <String>['nombre'],
      resolveRow: _row,
      // Al empezar la segunda plantilla (avance >= filas) se cancela.
      onProgress: (progress) {
        if (progress.current >= 2) {
          session.cancel();
        }
      },
    );

    expect(result.cancelled, isTrue);
    expect(result.exportedCount, 0);
    expect(result.writtenFiles, isEmpty);
    expect(destination.listSync(), isEmpty);
  });
}

Uint8List _docx(String paragraph) {
  final documentXml = <String>[
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<w:document xmlns:w="http://schemas.openxmlformats.org/',
    'wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>$paragraph</w:t>',
    '</w:r></w:p></w:body></w:document>',
  ].join();
  final archive = Archive()
    ..addFile(
      ArchiveFile(
        'word/document.xml',
        utf8.encode(documentXml).length,
        utf8.encode(documentXml),
      ),
    )
    ..addFile(
      ArchiveFile(
        '[Content_Types].xml',
        utf8.encode('<Types/>').length,
        utf8.encode('<Types/>'),
      ),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
