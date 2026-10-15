import 'package:forkumentos/features/mapping/domain/field_assignment.dart';

/// `fieldIndex` de una asignación cuyo campo ya no tiene columna en la
/// fuente de datos activa (columna eliminada o renombrada). La exportación ya
/// lo trata como valor vacío.
const int orphanFieldIndex = -1;

/// Resultado de reubicar asignaciones por nombre de columna.
final class HeaderRemapResult {
  const HeaderRemapResult({
    required this.assignments,
    required this.orphanHeaders,
    required this.changed,
  });

  /// Asignaciones con `fieldIndex` (y `fieldHeader`, si cambió la forma de
  /// escribir el nombre) ya resueltos contra los encabezados nuevos.
  final List<FieldAssignment> assignments;

  /// Encabezados distintos, en orden de aparición, de los campos que quedaron
  /// sin columna.
  final List<String> orphanHeaders;

  /// `true` si alguna asignación cambió respecto de la entrada.
  final bool changed;
}

/// Normaliza un encabezado para compararlo: sin espacios de más (incluidos
/// los no separables), sin distinguir mayúsculas ni tildes. La eñe se
/// conserva porque cambia el significado ("año" no es "ano").
String normalizeHeader(String header) {
  final buffer = StringBuffer();
  for (final rune in header.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_withoutAccent[char] ?? char);
  }
  return buffer.toString().replaceAll(_whitespace, ' ').trim();
}

final RegExp _whitespace = RegExp(r'[\s ​﻿]+');

const Map<String, String> _withoutAccent = <String, String>{
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
};

/// Reubica cada asignación en la columna de [headers] que lleva su nombre.
///
/// La identidad de un campo es su `fieldHeader`; el índice se vuelve a
/// resolver cada vez, de modo que insertar, quitar o reordenar columnas nunca
/// hace que un campo lea los datos de otra. Reglas:
///
/// 1. Coincidencia exacta de nombre.
/// 2. Si no hay, coincidencia normalizada (ver [normalizeHeader]) solo cuando
///    es inequívoca: una única columna libre y ningún otro campo con el mismo
///    nombre normalizado. En ese caso la asignación adopta la escritura de la
///    columna.
/// 3. Si no hay columna, la asignación queda con [orphanFieldIndex] y
///    conserva su `fieldHeader`.
///
/// Es idempotente: reaplicarla sobre su propio resultado no cambia nada.
HeaderRemapResult remapAssignmentsToHeaders({
  required List<FieldAssignment> assignments,
  required List<String> headers,
}) {
  final claimed = <int>{};
  final indexByHeader = <String, int>{};

  final distinctHeaders = <String>[];
  for (final assignment in assignments) {
    if (!distinctHeaders.contains(assignment.fieldHeader)) {
      distinctHeaders.add(assignment.fieldHeader);
    }
  }

  // Paso 1: coincidencias exactas reservan su columna.
  for (final header in distinctHeaders) {
    final index = headers.indexOf(header);
    if (index != -1) {
      indexByHeader[header] = index;
      claimed.add(index);
    }
  }

  // Paso 2: coincidencias normalizadas inequívocas sobre columnas libres.
  final unresolved = <String>[
    for (final header in distinctHeaders)
      if (!indexByHeader.containsKey(header)) header,
  ];
  final unresolvedByNormalized = <String, int>{};
  for (final header in unresolved) {
    final key = normalizeHeader(header);
    unresolvedByNormalized[key] = (unresolvedByNormalized[key] ?? 0) + 1;
  }
  for (final header in unresolved) {
    final key = normalizeHeader(header);
    if (key.isEmpty || unresolvedByNormalized[key] != 1) {
      continue;
    }
    final candidates = <int>[
      for (var index = 0; index < headers.length; index++)
        if (!claimed.contains(index) && normalizeHeader(headers[index]) == key)
          index,
    ];
    if (candidates.length == 1) {
      indexByHeader[header] = candidates.single;
      claimed.add(candidates.single);
    }
  }

  var changed = false;
  final remapped = <FieldAssignment>[];
  final orphans = <String>[];
  for (final assignment in assignments) {
    final index = indexByHeader[assignment.fieldHeader];
    final FieldAssignment next;
    if (index == null) {
      if (!orphans.contains(assignment.fieldHeader)) {
        orphans.add(assignment.fieldHeader);
      }
      next = assignment.fieldIndex == orphanFieldIndex
          ? assignment
          : assignment.copyWith(fieldIndex: orphanFieldIndex);
    } else if (assignment.fieldIndex == index &&
        assignment.fieldHeader == headers[index]) {
      next = assignment;
    } else {
      next = assignment.copyWith(
        fieldIndex: index,
        fieldHeader: headers[index],
      );
    }
    if (!identical(next, assignment)) {
      changed = true;
    }
    remapped.add(next);
  }

  return HeaderRemapResult(
    assignments: remapped,
    orphanHeaders: orphans,
    changed: changed,
  );
}

/// Propone, para cada encabezado de [orphanHeaders], la columna de [headers]
/// a la que probablemente se renombró. Solo devuelve propuestas inequívocas;
/// nunca se aplican solas (un renombre mal adivinado exportaría datos
/// equivocados).
///
/// Considera únicamente columnas que ninguna asignación usa ([claimedIndexes]
/// son las ya ocupadas). Reglas:
/// - un único huérfano y una única columna libre: se proponen entre sí;
/// - si no, una columna libre cuyo nombre normalizado contiene al del
///   huérfano (o al revés), siempre que sea la única que lo hace y ninguna
///   otra propuesta la use.
Map<String, int> suggestRenamedColumns({
  required List<String> orphanHeaders,
  required List<String> headers,
  required Set<int> claimedIndexes,
}) {
  final free = <int>[
    for (var index = 0; index < headers.length; index++)
      if (!claimedIndexes.contains(index)) index,
  ];
  if (orphanHeaders.length == 1 && free.length == 1) {
    return <String, int>{orphanHeaders.single: free.single};
  }

  final suggestions = <String, int>{};
  for (final orphan in orphanHeaders) {
    final orphanKey = normalizeHeader(orphan);
    if (orphanKey.length < 3) {
      continue;
    }
    final candidates = <int>[
      for (final index in free)
        if (_overlaps(orphanKey, normalizeHeader(headers[index]))) index,
    ];
    if (candidates.length == 1) {
      suggestions[orphan] = candidates.single;
    }
  }

  // Una columna propuesta para dos huérfanos distintos deja de ser clara.
  final timesSuggested = <int, int>{};
  for (final index in suggestions.values) {
    timesSuggested[index] = (timesSuggested[index] ?? 0) + 1;
  }
  suggestions.removeWhere((_, index) => timesSuggested[index]! > 1);
  return suggestions;
}

bool _overlaps(String a, String b) =>
    b.length >= 3 && (a.contains(b) || b.contains(a));
