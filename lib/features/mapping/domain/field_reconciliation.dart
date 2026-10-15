import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/header_remap.dart';

/// Un campo mapeado cuya columna ya no existe y que el usuario debe resolver:
/// decir a qué columna corresponde ahora o que se eliminó.
final class FieldReconciliationItem {
  const FieldReconciliationItem({
    required this.orphanHeader,
    required this.assignmentCount,
    this.suggestedIndex,
  });

  /// Nombre con el que el proyecto conoce el campo.
  final String orphanHeader;

  /// Cuántos lugares del documento usan este campo.
  final int assignmentCount;

  /// Columna a la que probablemente se renombró, si hay una propuesta
  /// inequívoca. Nunca se aplica sola.
  final int? suggestedIndex;
}

/// Campos sin columna de [assignments] frente a [headers], en orden de
/// aparición, con su propuesta de renombre cuando es inequívoca.
List<FieldReconciliationItem> buildFieldReconciliationItems({
  required List<FieldAssignment> assignments,
  required List<String> headers,
}) {
  final orphanCounts = <String, int>{};
  final claimed = <int>{};
  for (final assignment in assignments) {
    if (assignment.fieldIndex == orphanFieldIndex) {
      orphanCounts.update(
        assignment.fieldHeader,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    } else if (assignment.fieldIndex >= 0) {
      claimed.add(assignment.fieldIndex);
    }
  }
  if (orphanCounts.isEmpty) {
    return const <FieldReconciliationItem>[];
  }

  final suggestions = suggestRenamedColumns(
    orphanHeaders: orphanCounts.keys.toList(),
    headers: headers,
    claimedIndexes: claimed,
  );
  return <FieldReconciliationItem>[
    for (final entry in orphanCounts.entries)
      FieldReconciliationItem(
        orphanHeader: entry.key,
        assignmentCount: entry.value,
        suggestedIndex: suggestions[entry.key],
      ),
  ];
}
