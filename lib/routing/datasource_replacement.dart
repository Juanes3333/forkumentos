import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/domain/header_mismatch.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/header_mismatch_dialog.dart';

/// Importa [filePath] como fuente de datos activa. Si hay asignaciones cuyo
/// encabezado cambió de nombre en el nuevo archivo, primero pregunta al
/// usuario si acepta el cambio.
///
/// Devuelve `false` solo si el usuario canceló (no se importó nada). Un
/// fallo de importación devuelve `true`: el error queda en
/// `activeDatasourceProvider`, igual que con `importDatasource` directo.
Future<bool> importDatasourceConfirmingHeaders({
  required BuildContext context,
  required WidgetRef ref,
  required String filePath,
}) async {
  final assignments = ref.read(activeMappingProvider).state.assignments;
  var mismatches = const <HeaderMismatch>[];

  if (assignments.isNotEmpty) {
    try {
      final incoming = await ref
          .read(datasourceRepositoryProvider)
          .load(filePath);
      mismatches = detectHeaderMismatches(
        newHeaders: incoming.headers,
        assignments: assignments,
      );
    } on Object {
      // El archivo no se pudo leer: se deja que importDatasource reporte el
      // error por el camino habitual.
    }
  }

  var action = HeaderMismatchAction.skip;
  if (mismatches.isNotEmpty) {
    if (!context.mounted) {
      return false;
    }
    action = await showHeaderMismatchDialog(
      context: context,
      mismatches: mismatches,
    );
    if (action == HeaderMismatchAction.cancel) {
      return false;
    }
  }

  await ref
      .read(activeDatasourceProvider.notifier)
      .importDatasource(filePath: filePath);

  if (action == HeaderMismatchAction.acceptAndUpdate &&
      !ref.read(activeDatasourceProvider).hasError) {
    ref.read(activeMappingProvider.notifier).updateFieldHeaders(mismatches);
  }
  return true;
}
