import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/datasource/data/xlsx_sheet_parser.dart';

void main() {
  group('formatCellValue', () {
    test('celda nula produce null', () {
      expect(XlsxSheetParser.formatCellValue(null), isNull);
    });

    test('DateCellValue se formatea como YYYY-MM-DD, no ISO con hora', () {
      const value = DateCellValue(year: 2024, month: 1, day: 15);
      expect(XlsxSheetParser.formatCellValue(value), '2024-01-15');
    });

    test('DateTimeCellValue conserva fecha y hora legibles', () {
      const value = DateTimeCellValue(
        year: 2024,
        month: 3,
        day: 5,
        hour: 9,
        minute: 7,
      );
      expect(XlsxSheetParser.formatCellValue(value), '2024-03-05 09:07');
    });

    test(
      'DoubleCellValue típico conserva decimales sin notación científica',
      () {
        const value = DoubleCellValue(7500.5);
        expect(XlsxSheetParser.formatCellValue(value), '7500.5');
      },
    );

    test('DoubleCellValue extremo evita notación científica', () {
      const value = DoubleCellValue(0.0000001);
      final formatted = XlsxSheetParser.formatCellValue(value);
      expect(formatted, isNot(contains('e')));
      expect(formatted, isNot(contains('E')));
    });

    test('IntCellValue y TextCellValue pasan por toString sin cambios', () {
      expect(XlsxSheetParser.formatCellValue(const IntCellValue(42)), '42');
      expect(
        XlsxSheetParser.formatCellValue(TextCellValue('Bogotá')),
        'Bogotá',
      );
    });

    test('formato moneda se renderiza como pesos con puntos de miles', () {
      expect(
        XlsxSheetParser.formatCellValue(
          const IntCellValue(18414383),
          numberFormat: NumFormat.custom(formatCode: r'"$"#,##0'),
        ),
        r'$18.414.383',
      );
    });

    test('formato moneda con decimales conserva el separador , decimal', () {
      expect(
        XlsxSheetParser.formatCellValue(
          const DoubleCellValue(1234.5),
          numberFormat: NumFormat.custom(formatCode: r'[$$-240A]\ #,##0.00'),
        ),
        r'$1.234,50',
      );
    });

    test('formato con miles pero sin moneda agrupa sin símbolo', () {
      expect(
        XlsxSheetParser.formatCellValue(
          const IntCellValue(1000000),
          numberFormat: NumFormat.custom(formatCode: '#,##0'),
        ),
        '1.000.000',
      );
    });

    test('formato porcentaje multiplica por 100 y agrega %', () {
      expect(
        XlsxSheetParser.formatCellValue(
          const DoubleCellValue(0.075),
          numberFormat: NumFormat.custom(formatCode: '0.0%'),
        ),
        '7,5%',
      );
    });

    test('formato numérico plano (0.00) deja el valor crudo', () {
      expect(
        XlsxSheetParser.formatCellValue(
          const DoubleCellValue(7500.5),
          numberFormat: NumFormat.custom(formatCode: '0.00'),
        ),
        '7500.5',
      );
    });

    test('valor negativo en formato moneda antepone el signo', () {
      expect(
        XlsxSheetParser.formatCellValue(
          const IntCellValue(-2500),
          numberFormat: NumFormat.custom(formatCode: r'"$"#,##0'),
        ),
        r'-$2.500',
      );
    });
  });

  group('decodeWorkbook', () {
    test('un .xlsx normal se decodifica sin tocar nada', () {
      final bytes = _workbookBytes();
      final workbook = XlsxSheetParser.decodeWorkbook(bytes);
      expect(workbook.tables, isNotEmpty);
    });

    test(
      'recupera un .xlsx con <numFmt> en el rango integrado (formato moneda)',
      () {
        final poisoned = _withBuiltinNumFmtOverride(_workbookBytes());

        // Documenta el bug del paquete `excel` 4.0.6 que estamos sorteando.
        expect(
          () => Excel.decodeBytes(poisoned),
          throwsA(anything),
        );

        final workbook = XlsxSheetParser.decodeWorkbook(poisoned);
        expect(workbook.tables, isNotEmpty);
      },
    );

    test('un .xlsx corrupto de verdad sigue lanzando FormatException', () {
      expect(
        () => XlsxSheetParser.decodeWorkbook(<int>[1, 2, 3, 4, 5]),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

List<int> _workbookBytes() {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!]
    ..appendRow(<CellValue?>[
      TextCellValue('nombre'),
      TextCellValue('monto'),
    ])
    ..appendRow(<CellValue?>[
      TextCellValue('Ana'),
      const IntCellValue(12345670),
    ]);
  expect(sheet.rows, hasLength(2));

  final encoded = excel.encode();
  if (encoded == null) {
    throw StateError('No se pudo codificar el workbook de prueba.');
  }
  return encoded;
}

/// Injects `<numFmt numFmtId="5" .../>` (built-in currency id) into
/// `xl/styles.xml`, which `excel` 4.0.6 refuses to decode.
List<int> _withBuiltinNumFmtOverride(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final output = Archive();
  const injected =
      '<numFmts count="1"><numFmt numFmtId="5" formatCode="0.00"/></numFmts>';

  for (final file in archive.files) {
    if (file.name.toLowerCase() == 'xl/styles.xml') {
      final xml = utf8
          .decode(file.content as List<int>)
          .replaceFirstMapped(
            RegExp('<styleSheet[^>]*>'),
            (match) => '${match.group(0)}$injected',
          );
      final data = utf8.encode(xml);
      output.addFile(ArchiveFile('xl/styles.xml', data.length, data));
    } else {
      final content = file.content as List<int>;
      output.addFile(ArchiveFile(file.name, content.length, content));
    }
  }

  final encoded = ZipEncoder().encode(output);
  if (encoded == null) {
    throw StateError('No se pudo re-empaquetar el workbook de prueba.');
  }
  return encoded;
}
