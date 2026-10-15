import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/domain/field_reconciliation.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

/// Campos mapeados cuya columna ya no existe en la fuente de datos activa.
/// Vacío mientras no haya fuente de datos con encabezados.
final fieldReconciliationProvider = Provider<List<FieldReconciliationItem>>((
  ref,
) {
  final headers = ref.watch(
    activeDatasourceProvider.select((state) => state.valueOrNull?.headers),
  );
  if (headers == null || headers.isEmpty) {
    return const <FieldReconciliationItem>[];
  }
  final assignments = ref.watch(
    activeMappingProvider.select((session) => session.state.assignments),
  );
  return buildFieldReconciliationItems(
    assignments: assignments,
    headers: headers,
  );
});

/// Campos sin columna que el usuario ya vio y dejó para después: no se vuelve
/// a abrir el diálogo por ellos (queda el indicador de la barra de estado).
/// Se reinicia al cambiar de proyecto.
final dismissedOrphanHeadersProvider = StateProvider<Set<String>>((ref) {
  ref.watch(activeProjectProvider.select((state) => state.valueOrNull?.id));
  return <String>{};
});
