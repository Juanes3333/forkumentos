import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/mapping_review.dart';
import 'package:forkumentos/features/mapping/domain/mapping_validation.dart';

void main() {
  group('isExportReady', () {
    test('es verdadero cuando solo faltan campos (soft-gate)', () {
      final validation = validateMappingAssignments(
        assignments: const [],
        datasourceHeaders: <String>['nombre'],
      );

      expect(
        isExportReady(validation: validation, invalidAssignmentIds: const []),
        isTrue,
      );
    });

    test('es falso cuando hay solapes', () {
      const validation = MappingValidationResult(
        missingFieldIndexes: <int>[],
        duplicateAssignmentIds: <String>[],
        overlaps: <MappingOverlap>[MappingOverlap(firstId: 'a', secondId: 'b')],
      );

      expect(
        isExportReady(validation: validation, invalidAssignmentIds: const []),
        isFalse,
      );
    });
  });
}
