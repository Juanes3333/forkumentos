import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/domain/field_reconciliation.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/field_reconciliation_provider.dart';

/// Abre el diálogo que resuelve los campos cuya columna ya no existe. Vive en
/// la misma ventana de la app. Al cerrarlo, los campos que sigan sin resolver
/// se anotan como vistos para no volver a abrirlo solo por ellos.
Future<void> showFieldReconciliationDialog(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  await showDialog<void>(
    context: context,
    builder: (context) => const FieldReconciliationDialog(),
  );
  container.read(dismissedOrphanHeadersProvider.notifier).state = <String>{
    for (final item in container.read(fieldReconciliationProvider))
      item.orphanHeader,
  };
}

/// Diálogo de reconciliación: pasa por los campos sin columna de uno en uno
/// ("1 de N"). Para cada uno se elige la columna a la que se renombró o se
/// marca como eliminado. Ambas acciones son una sola operación deshacible.
final class FieldReconciliationDialog extends ConsumerStatefulWidget {
  const FieldReconciliationDialog({super.key});

  @override
  ConsumerState<FieldReconciliationDialog> createState() =>
      _FieldReconciliationDialogState();
}

final class _FieldReconciliationDialogState
    extends ConsumerState<FieldReconciliationDialog> {
  int _position = 0;
  bool _closing = false;

  /// Columna elegida por el usuario para cada campo (gana a la sugerencia).
  final Map<String, int> _chosenColumn = <String, int>{};

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(fieldReconciliationProvider);
    final headers =
        ref.watch(activeDatasourceProvider).valueOrNull?.headers ??
        const <String>[];

    if (items.isEmpty) {
      if (!_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Si el usuario ya lo cerró en este mismo frame, no hay nada que
          // cerrar (un segundo pop cerraría la ruta de debajo).
          if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
            Navigator.of(context).pop();
          }
        });
      }
      return const SizedBox.shrink();
    }

    final position = _position.clamp(0, items.length - 1);
    final item = items[position];
    final selected = _chosenColumn[item.orphanHeader] ?? item.suggestedIndex;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.foregroundMuted,
    );
    final usage = item.assignmentCount == 1
        ? 'Se usa en 1 lugar del documento.'
        : 'Se usa en ${item.assignmentCount} lugares del documento.';

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: colors.warning),
          const SizedBox(width: 12),
          const Expanded(child: Text('Cambiaron las columnas del Excel')),
          if (items.length > 1) ...<Widget>[
            IconButton(
              tooltip: 'Campo anterior',
              icon: const Icon(Icons.chevron_left),
              onPressed: position == 0
                  ? null
                  : () => setState(() => _position = position - 1),
            ),
            Text('${position + 1} de ${items.length}'),
            IconButton(
              tooltip: 'Campo siguiente',
              icon: const Icon(Icons.chevron_right),
              onPressed: position == items.length - 1
                  ? null
                  : () => setState(() => _position = position + 1),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  const TextSpan(text: 'El campo '),
                  TextSpan(
                    text: '«${item.orphanHeader}»',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' ya no está en el Excel.'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(usage, style: muted),
            const SizedBox(height: 20),
            const Text('¿Cambió de nombre? Elige la columna que corresponde:'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey<String>(item.orphanHeader),
                    isExpanded: true,
                    initialValue: selected,
                    hint: const Text('Elige una columna'),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<int>>[
                      for (var index = 0; index < headers.length; index++)
                        DropdownMenuItem<int>(
                          value: index,
                          child: Text(
                            '${_columnLetter(index)} · ${headers[index]}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(
                          () => _chosenColumn[item.orphanHeader] = value,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => _rename(item, selected, headers),
                  child: const Text('Es este campo'),
                ),
              ],
            ),
            if (item.suggestedIndex != null &&
                item.suggestedIndex! < headers.length) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Sugerencia: «${headers[item.suggestedIndex!]}». Revísala '
                'antes de confirmar.',
                style: muted,
              ),
            ],
            const SizedBox(height: 20),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: 16),
            const Text('¿Ya no existe en el Excel?'),
            const SizedBox(height: 4),
            Text(
              'Se quitan sus asignaciones del documento. Puedes deshacerlo '
              'con Ctrl+Z.',
              style: muted,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => _remove(item),
                child: const Text('Se eliminó'),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Resolver después'),
        ),
      ],
    );
  }

  void _rename(
    FieldReconciliationItem item,
    int columnIndex,
    List<String> headers,
  ) {
    if (columnIndex >= headers.length) {
      return;
    }
    ref
        .read(activeMappingProvider.notifier)
        .renameOrphanField(
          orphanHeader: item.orphanHeader,
          toHeader: headers[columnIndex],
          toIndex: columnIndex,
        );
    _chosenColumn.remove(item.orphanHeader);
  }

  void _remove(FieldReconciliationItem item) {
    ref
        .read(activeMappingProvider.notifier)
        .removeOrphanField(item.orphanHeader);
    _chosenColumn.remove(item.orphanHeader);
  }
}

/// Convierte un índice 0-based en la letra de columna de Excel (A, B, …, Z,
/// AA, …).
String _columnLetter(int index) {
  var result = '';
  var n = index;
  while (n >= 0) {
    result = String.fromCharCode(65 + n % 26) + result;
    n = n ~/ 26 - 1;
  }
  return result;
}
