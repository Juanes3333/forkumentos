import 'package:forkumentos/features/mapping/domain/field_assignment.dart';

/// Discrepancia entre el encabezado que recuerdan las asignaciones de una
/// columna y el encabezado real de esa columna en una nueva fuente de datos.
final class HeaderMismatch {
  const HeaderMismatch({
    required this.fieldIndex,
    required this.expectedHeader,
    required this.actualHeader,
    required this.affectedAssignmentIds,
  });

  /// Índice de la columna (0-based).
  final int fieldIndex;

  /// Encabezado que el proyecto esperaba.
  final String expectedHeader;

  /// Encabezado en la nueva fuente de datos.
  final String actualHeader;

  /// Ids de las asignaciones que usan esta columna.
  final List<String> affectedAssignmentIds;
}

/// Compara [newHeaders] contra el `fieldHeader` que recuerda cada asignación
/// y devuelve una discrepancia por columna, ordenadas por índice.
///
/// Las asignaciones cuya columna ya no existe en [newHeaders] se ignoran: no
/// hay un nombre nuevo que aceptar y `findInvalidAssignmentIds` ya las marca
/// como inválidas.
List<HeaderMismatch> detectHeaderMismatches({
  required List<String> newHeaders,
  required List<FieldAssignment> assignments,
}) {
  final expectedByIndex = <int, String>{};
  final idsByIndex = <int, List<String>>{};

  for (final assignment in assignments) {
    final index = assignment.fieldIndex;
    if (index < 0 || index >= newHeaders.length) {
      continue;
    }
    if (newHeaders[index] == assignment.fieldHeader) {
      continue;
    }
    expectedByIndex.putIfAbsent(index, () => assignment.fieldHeader);
    idsByIndex.putIfAbsent(index, () => <String>[]).add(assignment.id);
  }

  final indexes = expectedByIndex.keys.toList()..sort();
  return <HeaderMismatch>[
    for (final index in indexes)
      HeaderMismatch(
        fieldIndex: index,
        expectedHeader: expectedByIndex[index]!,
        actualHeader: newHeaders[index],
        affectedAssignmentIds: List<String>.unmodifiable(idsByIndex[index]!),
      ),
  ];
}

/// Devuelve [assignments] con el `fieldHeader` de cada asignación afectada
/// por [mismatches] reemplazado por el encabezado nuevo.
List<FieldAssignment> applyHeaderMismatches(
  List<FieldAssignment> assignments,
  List<HeaderMismatch> mismatches,
) {
  final headerById = <String, String>{
    for (final mismatch in mismatches)
      for (final id in mismatch.affectedAssignmentIds)
        id: mismatch.actualHeader,
  };

  return <FieldAssignment>[
    for (final assignment in assignments)
      if (headerById[assignment.id] case final header?)
        assignment.copyWith(fieldHeader: header)
      else
        assignment,
  ];
}
