import 'package:flutter/material.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/mapping/domain/header_mismatch.dart';

/// Acción elegida en el diálogo de encabezados que no coinciden.
enum HeaderMismatchAction {
  /// Usa la nueva fuente y actualiza el `fieldHeader` de las asignaciones.
  acceptAndUpdate,

  /// Usa la nueva fuente sin actualizar: las asignaciones afectadas quedan
  /// inválidas y hay que volver a mapearlas.
  skip,

  /// Aborta el reemplazo de la fuente de datos.
  cancel,
}

/// Muestra las discrepancias entre encabezados y devuelve la acción elegida.
Future<HeaderMismatchAction> showHeaderMismatchDialog({
  required BuildContext context,
  required List<HeaderMismatch> mismatches,
}) async {
  final result = await showDialog<HeaderMismatchAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) => HeaderMismatchDialog(mismatches: mismatches),
  );
  return result ?? HeaderMismatchAction.cancel;
}

final class HeaderMismatchDialog extends StatelessWidget {
  const HeaderMismatchDialog({required this.mismatches, super.key});

  final List<HeaderMismatch> mismatches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.foregroundMuted,
    );
    final count = mismatches.length;
    final summary = count == 1
        ? 'El nuevo archivo tiene 1 encabezado distinto al del proyecto:'
        : 'El nuevo archivo tiene $count encabezados distintos a los del '
              'proyecto:';

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: colors.warning),
          const SizedBox(width: 12),
          const Expanded(child: Text('Los encabezados no coinciden')),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(summary),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const <int, TableColumnWidth>{
                    0: FixedColumnWidth(48),
                    1: FlexColumnWidth(),
                    2: FixedColumnWidth(32),
                    3: FlexColumnWidth(),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: <TableRow>[
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: colors.border),
                        ),
                      ),
                      children: <Widget>[
                        _HeaderCell('Col.', style: theme.textTheme.labelSmall),
                        _HeaderCell(
                          'Proyecto',
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox.shrink(),
                        _HeaderCell(
                          'Nuevo archivo',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    for (final mismatch in mismatches)
                      TableRow(
                        children: <Widget>[
                          _BodyCell(
                            Text(
                              excelColumnLetter(mismatch.fieldIndex),
                              style: muted,
                            ),
                          ),
                          _BodyCell(
                            Text(
                              mismatch.expectedHeader,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.foregroundMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          _BodyCell(
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: colors.foregroundMuted,
                            ),
                          ),
                          _BodyCell(
                            Text(
                              mismatch.actualHeader,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '• Aceptar y actualizar: el proyecto adopta los nombres del '
              'nuevo archivo y conserva el mapeo.\n'
              '• Omitir: usa el nuevo archivo sin actualizar los nombres; las '
              'asignaciones de esas columnas quedarán inválidas.',
              style: muted,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        Row(
          children: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(HeaderMismatchAction.skip),
              child: const Text('Omitir'),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(HeaderMismatchAction.cancel),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(HeaderMismatchAction.acceptAndUpdate),
              child: const Text('Aceptar y actualizar'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Convierte un índice 0-based en la letra de columna de Excel
/// (A, B, …, Z, AA, …).
String excelColumnLetter(int index) {
  var result = '';
  var n = index;
  while (n >= 0) {
    result = String.fromCharCode(65 + n % 26) + result;
    n = n ~/ 26 - 1;
  }
  return result;
}

final class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: style),
    );
  }
}

final class _BodyCell extends StatelessWidget {
  const _BodyCell(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: child,
    );
  }
}
