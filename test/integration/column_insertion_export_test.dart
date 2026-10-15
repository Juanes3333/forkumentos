import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/export/data/docx_export_command.dart';
import 'package:forkumentos/features/export/domain/export_placeholder.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/header_remap.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';

import '../support/fakes.dart';

/// El caso del cliente: el Excel gana una columna en medio y el export debe
/// seguir leyendo cada campo de su propia columna (antes salían datos de la
/// columna vecina o la exportación se bloqueaba).
void main() {
  late Directory tempDirectory;
  late List<String> headers;
  late ProviderContainer container;
  var imports = 0;

  setUp(() async {
    imports = 0;
    headers = <String>['nombre', 'teléfono', 'cédula', 'correo'];
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_column_insertion_',
    );
    container = ProviderContainer(
      overrides: <Override>[
        loggingServiceProvider.overrideWithValue(FakeLoggingService()),
        datasourceRepositoryProvider.overrideWithValue(
          FakeDatasourceRepository(
            loadHandler: (path) async => Datasource(
              sourcePath: path,
              fileName: path,
              fileSizeBytes: 1,
              importedAt: DateTime.utc(2026),
              format: DatasourceFormat.csv,
              headers: headers,
              previewRow: List<String?>.filled(headers.length, null),
              rowCount: 1,
              emptyColumnIndexes: const <int>[],
            ),
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tempDirectory.delete(recursive: true);
  });

  Future<void> replaceColumns(List<String> next) async {
    headers = next;
    imports++;
    await container
        .read(activeDatasourceProvider.notifier)
        .importDatasource(filePath: 'datos_$imports.csv');
  }

  /// Exporta una fila con las asignaciones vigentes (como hace el lanzador:
  /// índice y valor salen de los mismos encabezados) y devuelve el texto.
  Future<String> exportText({
    required List<FieldAssignment> assignments,
    required List<String?> row,
  }) async {
    expect(
      assignmentsMatchHeaders(assignments: assignments, headers: headers),
      isTrue,
      reason: 'la guarda del lanzador debe aceptar las asignaciones',
    );
    final command = DocxExportCommand(
      templateBytes: _template('Cédula: CED. Correo: COR.'),
      destinationFolder: tempDirectory.path,
      filenamePattern: const FilenamePattern(
        blocks: <FilenamePatternBlock>[FilenameTextBlock('doc')],
      ),
      rowIndexes: const <int>[0],
      placeholders: <ExportPlaceholder>[
        for (final assignment in assignments)
          ExportPlaceholder(
            steps: const <ExportPathStep>[
              ExportPathStep.rootBlock(blockIndex: 0),
            ],
            startOffset: assignment.startOffset,
            endOffset: assignment.endOffset,
            fieldIndex: assignment.fieldIndex,
          ),
      ],
      headers: List<String>.of(headers),
      templateBaseName: 'plantilla',
      resolveRow: _fixedRow(row),
    );
    final result = await command.execute();
    expect(result.errors, isEmpty);
    expect(result.exportedCount, 1);
    final archive = ZipDecoder().decodeBytes(
      File(result.writtenFiles.single).readAsBytesSync(),
    );
    final document = archive.files.firstWhere(
      (file) => file.name == 'word/document.xml',
    );
    return utf8.decode(document.content as List<int>);
  }

  Future<ActiveMappingNotifier> mapCedulaAndCorreo() async {
    final mapping = container.read(activeMappingProvider.notifier);
    await replaceColumns(headers);
    // "CED" ocupa los offsets 8..11 y "COR" los 21..24 del párrafo.
    mapping
      ..confirmAssignment(
        selection: _selection('CED', 8, 11),
        fieldHeader: 'cédula',
        fieldIndex: 2,
        headerCount: 4,
      )
      ..confirmAssignment(
        selection: _selection('COR', 21, 24),
        fieldHeader: 'correo',
        fieldIndex: 3,
        headerCount: 4,
      );
    return mapping;
  }

  List<FieldAssignment> assignments() =>
      container.read(activeMappingProvider).state.assignments;

  test(
    'con una columna insertada el export lee cada campo de su columna',
    () async {
      await mapCedulaAndCorreo();
      await replaceColumns(<String>[
        'nombre',
        'teléfono',
        'tipo de documento',
        'cédula',
        'correo',
      ]);

      final xml = await exportText(
        assignments: assignments(),
        row: const <String?>['Ana', '300', 'CC', '12345', 'ana@x.co'],
      );

      expect(xml, contains('Cédula: 12345. Correo: ana@x.co.'));
      expect(xml, isNot(contains('CC')));
    },
  );

  test('deshacer una asignación anterior no vuelve a leer la columna '
      'vecina', () async {
    final mapping = await mapCedulaAndCorreo();
    await replaceColumns(<String>[
      'nombre',
      'teléfono',
      'tipo de documento',
      'cédula',
      'correo',
    ]);

    // Se deshace la asignación de correo: la de cédula sigue en la columna
    // nueva (3), no en la vieja (2) que ahora es "tipo de documento".
    mapping.undo();

    final xml = await exportText(
      assignments: assignments(),
      row: const <String?>['Ana', '300', 'CC', '12345', 'ana@x.co'],
    );

    expect(xml, contains('Cédula: 12345. Correo: COR.'));
    expect(xml, isNot(contains('CC')));
  });

  test('un campo sin columna se exporta vacío sin tocar los demás', () async {
    await mapCedulaAndCorreo();
    await replaceColumns(<String>['nombre', 'teléfono', 'correo']);

    final xml = await exportText(
      assignments: assignments(),
      row: const <String?>['Ana', '300', 'ana@x.co'],
    );

    expect(xml, contains('Cédula: . Correo: ana@x.co.'));
  });
}

/// Fuera del `main` para que el closure solo capture la fila: el comando se
/// copia a un isolate y el contexto del test (con su `ProviderContainer`) no
/// se puede enviar.
Future<List<String?>> Function(int) _fixedRow(List<String?> row) =>
    (_) async => row;

DocumentTextSelection _selection(String text, int start, int end) {
  return DocumentTextSelection(
    path: const DocumentTextPath(
      steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 0)],
    ),
    startOffset: start,
    endOffset: end,
    selectedText: text,
  );
}

Uint8List _template(String paragraph) {
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
