import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/data/datasource_repository_provider.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/domain/header_mismatch.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/header_mismatch_dialog.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

/// Importa [filePath] como fuente de datos activa. Si algún encabezado del
/// nuevo archivo no coincide con lo que el proyecto espera, primero pregunta
/// al usuario si acepta el cambio.
///
/// Devuelve `false` solo si el usuario canceló (no se importó nada). Un
/// fallo de importación devuelve `true`: el error queda en
/// `activeDatasourceProvider`, igual que con `importDatasource` directo.
Future<bool> importDatasourceConfirmingHeaders({
  required BuildContext context,
  required WidgetRef ref,
  required String filePath,
}) async {
  final confirmation = await _confirmHeaderChanges(
    context: context,
    ref: ref,
    filePath: filePath,
  );
  if (confirmation == null) {
    return false;
  }

  await ref
      .read(activeDatasourceProvider.notifier)
      .importDatasource(filePath: filePath);

  if (!ref.read(activeDatasourceProvider).hasError) {
    _applyConfirmation(ref, confirmation);
  }
  return true;
}

/// Vuelve a leer la fuente de datos desde su ruta original (ver
/// `ActiveDatasourceNotifier.refreshDatasource`) con la misma confirmación
/// de encabezados que [importDatasourceConfirmingHeaders].
///
/// Devuelve `null` si el usuario canceló (no se refrescó nada).
Future<DatasourceRefreshResult?> refreshDatasourceConfirmingHeaders({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final externalPath = ref
      .read(activeProjectProvider)
      .valueOrNull
      ?.datasourceExternalPath;

  var confirmation = const _HeaderConfirmation.none();
  if (externalPath != null && externalPath.isNotEmpty) {
    final result = await _confirmHeaderChanges(
      context: context,
      ref: ref,
      filePath: externalPath,
    );
    if (result == null) {
      return null;
    }
    confirmation = result;
  }

  final refresh = await ref
      .read(activeDatasourceProvider.notifier)
      .refreshDatasource();
  if (refresh.status == DatasourceRefreshStatus.updated) {
    _applyConfirmation(ref, confirmation);
  }
  return refresh;
}

final class _HeaderConfirmation {
  const _HeaderConfirmation(this.action, this.mismatches);

  const _HeaderConfirmation.none()
    : action = HeaderMismatchAction.skip,
      mismatches = const <HeaderMismatch>[];

  final HeaderMismatchAction action;
  final List<HeaderMismatch> mismatches;
}

/// Lee los encabezados de [filePath] sin activarlo y, si difieren de los
/// del proyecto, pregunta al usuario. Devuelve `null` si canceló.
Future<_HeaderConfirmation?> _confirmHeaderChanges({
  required BuildContext context,
  required WidgetRef ref,
  required String filePath,
}) async {
  final assignments = ref.read(activeMappingProvider).state.assignments;
  final currentHeaders =
      ref.read(activeDatasourceProvider).valueOrNull?.headers ??
      const <String>[];
  if (assignments.isEmpty && currentHeaders.isEmpty) {
    return const _HeaderConfirmation.none();
  }

  final List<HeaderMismatch> mismatches;
  try {
    final incoming = await ref
        .read(datasourceRepositoryProvider)
        .load(filePath);
    mismatches = detectHeaderMismatches(
      newHeaders: incoming.headers,
      assignments: assignments,
      currentHeaders: currentHeaders,
    );
  } on Object {
    // El archivo no se pudo leer: se deja que la importación o el refresco
    // reporten el error por el camino habitual.
    return const _HeaderConfirmation.none();
  }

  if (mismatches.isEmpty) {
    return const _HeaderConfirmation.none();
  }
  if (!context.mounted) {
    return null;
  }
  final action = await showHeaderMismatchDialog(
    context: context,
    mismatches: mismatches,
  );
  if (action == HeaderMismatchAction.cancel) {
    return null;
  }
  return _HeaderConfirmation(action, mismatches);
}

void _applyConfirmation(WidgetRef ref, _HeaderConfirmation confirmation) {
  if (confirmation.action == HeaderMismatchAction.acceptAndUpdate) {
    ref
        .read(activeMappingProvider.notifier)
        .updateFieldHeaders(confirmation.mismatches);
  }
}
