import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';

void main() {
  group('FilenamePattern.sanitize', () {
    test('reemplaza caracteres inválidos y recorta', () {
      expect(FilenamePattern.sanitize(r'  Juan<>:"/\|?*  '), 'Juan_________');
      expect(FilenamePattern.sanitize('...'), 'documento');
      expect(FilenamePattern.sanitize(''), 'documento');
    });
  });

  group('FilenamePattern.dedupe', () {
    test('añade (2)(3) sin sobrescribir', () {
      final used = <String>{'contrato'};
      expect(FilenamePattern.dedupe('contrato', used), 'contrato (2)');
      used.add('contrato (2)'.toLowerCase());
      expect(FilenamePattern.dedupe('contrato', used), 'contrato (3)');
    });

    test('es case-insensitive contra nombres usados', () {
      final used = <String>{'ana'};
      expect(FilenamePattern.dedupe('Ana', used), 'Ana (2)');
    });
  });

  group('FilenamePattern.resolve', () {
    test('combina texto y campos con sanitizado', () {
      const pattern = FilenamePattern(
        blocks: <FilenamePatternBlock>[
          FilenameTextBlock('Contrato - '),
          FilenameFieldBlock(fieldIndex: 0, fieldHeader: 'nombre'),
        ],
      );

      expect(
        pattern.resolve(
          row: <String?>['Ana/Pérez'],
          headers: <String>['nombre'],
        ),
        'Contrato - Ana_Pérez',
      );
    });
  });
}
