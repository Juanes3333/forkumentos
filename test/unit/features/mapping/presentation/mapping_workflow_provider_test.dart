import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/mapping/domain/mapping_review.dart';
import 'package:forkumentos/features/mapping/domain/mapping_validation.dart';

void main() {
  group('isExportReady', () {
    test('es falso cuando hay campos faltantes', () {
      final validation = validateMappingAssignments(
        assignments: const [],
        datasourceHeaders: <String>['nombre'],
      );

      expect(
        isExportReady(validation: validation, invalidAssignmentIds: const []),
        isFalse,
      );
    });
  });
}
