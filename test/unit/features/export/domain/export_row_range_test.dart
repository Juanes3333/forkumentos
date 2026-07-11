import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/export/domain/export_row_range.dart';

void main() {
  group('ExportRowRange.parse', () {
    test('parsea rangos, únicos y ordenados en 0-based', () {
      expect(
        ExportRowRange.parse('1-20,15,18-25', rowCount: 30),
        List<int>.generate(25, (index) => index),
      );
    });

    test('acepta filas sueltas y clampa al rowCount', () {
      expect(ExportRowRange.parse('1, 3, 99', rowCount: 5), <int>[0, 2, 4]);
    });

    test('invierte rangos descendentes', () {
      expect(ExportRowRange.parse('5-2', rowCount: 10), <int>[1, 2, 3, 4]);
    });

    test('cadena vacía produce lista vacía', () {
      expect(ExportRowRange.parse('  ', rowCount: 10), isEmpty);
    });

    test('rechaza tokens inválidos', () {
      expect(
        () => ExportRowRange.parse('a-b', rowCount: 10),
        throwsFormatException,
      );
      expect(
        () => ExportRowRange.parse('0', rowCount: 10),
        throwsFormatException,
      );
      expect(
        () => ExportRowRange.parse('1,,3', rowCount: 10),
        throwsFormatException,
      );
    });
  });
}
