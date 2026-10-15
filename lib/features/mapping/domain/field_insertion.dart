import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

/// Ordena dos posiciones del documento en orden de lectura: encabezado,
/// cuerpo y pie; dentro del cuerpo por bloque (y, en tablas, por fila, celda
/// y bloque de la celda) y por último por desplazamiento en el párrafo.
/// Devuelve negativo si la posición A va antes que la B, positivo si va
/// después y cero si es la misma posición.
int compareDocumentPositions({
  required DocumentTextPath pathA,
  required int offsetA,
  required DocumentTextPath pathB,
  required int offsetB,
}) {
  final region = _regionOrder(
    pathA.region,
  ).compareTo(_regionOrder(pathB.region));
  if (region != 0) {
    return region;
  }
  final keysA = _keys(pathA);
  final keysB = _keys(pathB);
  final shared = keysA.length < keysB.length ? keysA.length : keysB.length;
  for (var i = 0; i < shared; i++) {
    final order = keysA[i].compareTo(keysB[i]);
    if (order != 0) {
      return order;
    }
  }
  if (keysA.length != keysB.length) {
    return keysA.length.compareTo(keysB.length);
  }
  return offsetA.compareTo(offsetB);
}

/// Orden de lectura de las regiones (el enum declara el cuerpo primero).
int _regionOrder(DocumentTextRegion region) => switch (region) {
  DocumentTextRegion.header => 0,
  DocumentTextRegion.body => 1,
  DocumentTextRegion.footer => 2,
};

List<int> _keys(DocumentTextPath path) => <int>[
  for (final step in path.steps)
    ...switch (step) {
      RootDocumentBlockStep(:final blockIndex) => <int>[blockIndex],
      DocumentTableCellBlockStep(
        :final rowIndex,
        :final cellIndex,
        :final blockIndex,
      ) =>
        <int>[rowIndex, cellIndex, blockIndex],
    },
];

/// Posición (0-based) donde debe quedar la columna de un campo nuevo para que
/// las columnas sigan el orden del documento: justo después de la columna del
/// campo mapeado más cercano que va antes del texto seleccionado ([path],
/// [offset]) o, si no hay ninguno antes, justo antes de la del primero que va
/// después. Sin campos mapeados, al final ([headerCount]). Los campos sin
/// columna no cuentan.
int insertionIndexForNewField({
  required List<FieldAssignment> assignments,
  required DocumentTextPath path,
  required int offset,
  required int headerCount,
}) {
  FieldAssignment? previous;
  FieldAssignment? next;
  for (final assignment in assignments) {
    if (assignment.fieldIndex < 0) {
      continue;
    }
    final order = compareDocumentPositions(
      pathA: assignment.path,
      offsetA: assignment.startOffset,
      pathB: path,
      offsetB: offset,
    );
    if (order < 0) {
      if (previous == null ||
          compareDocumentPositions(
                pathA: assignment.path,
                offsetA: assignment.startOffset,
                pathB: previous.path,
                offsetB: previous.startOffset,
              ) >
              0) {
        previous = assignment;
      }
    } else if (next == null ||
        compareDocumentPositions(
              pathA: assignment.path,
              offsetA: assignment.startOffset,
              pathB: next.path,
              offsetB: next.startOffset,
            ) <
            0) {
      next = assignment;
    }
  }
  if (previous != null) {
    return (previous.fieldIndex + 1).clamp(0, headerCount);
  }
  if (next != null) {
    return next.fieldIndex.clamp(0, headerCount);
  }
  return headerCount;
}
