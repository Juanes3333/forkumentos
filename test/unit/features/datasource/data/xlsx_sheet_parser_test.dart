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
  });
}
