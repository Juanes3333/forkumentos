import 'package:flutter/material.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/mapping/domain/mapping_color_palette.dart';
import 'package:forkumentos/features/mapping/domain/mapping_field_status.dart';

final class MappingFieldSidebar extends StatelessWidget {
  const MappingFieldSidebar({
    required this.headers,
    required this.previewRow,
    required this.currentFieldIndex,
    required this.assignmentCounts,
    required this.onFieldSelected,
    required this.onFieldHoverChanged,
    required this.onRemoveFieldAssignments,
    this.showParagraphSpanControls = false,
    this.currentFieldParagraphSpan,
    this.onIncludeNextParagraph,
    this.onExcludeLastParagraph,
    super.key,
  });

  final List<String> headers;
  final List<String?> previewRow;
  final int currentFieldIndex;
  final List<int> assignmentCounts;
  final ValueChanged<int> onFieldSelected;
  final ValueChanged<int?> onFieldHoverChanged;
  final ValueChanged<int> onRemoveFieldAssignments;

  /// Cuando es `true`, se muestran los controles de "Incluir/Excluir
  /// siguiente párrafo" debajo del campo activo. El llamador decide esto:
  /// requiere al menos una asignación en el campo activo, cuyo párrafo no
  /// pertenezca a una lista numerada (esas usan auto-detección por numId) ni
  /// esté marcado manualmente como campo de lista.
  final bool showParagraphSpanControls;

  /// Cuántos párrafos abarca la asignación activa. `null` o `1` = un solo
  /// párrafo.
  final int? currentFieldParagraphSpan;
  final VoidCallback? onIncludeNextParagraph;
  final VoidCallback? onExcludeLastParagraph;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SizedBox(
        width: 260,
        child: ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: headers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final color = mappingColorForFieldIndex(index);
            final isActive = index == currentFieldIndex;
            final count = assignmentCounts[index];
            final status = count > 0
                ? MappingFieldStatus.assigned
                : MappingFieldStatus.pending;
            final previewValue = index < previewRow.length
                ? previewRow[index]
                : null;

            return MouseRegion(
              onEnter: (_) => onFieldHoverChanged(index),
              onExit: (_) => onFieldHoverChanged(null),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ListTile(
                    selected: isActive,
                    leading: Icon(Icons.circle, size: 12, color: color),
                    title: Text(headers[index]),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          status == MappingFieldStatus.assigned
                              ? '$count asignación${count == 1 ? '' : 'es'}'
                              : 'Pendiente',
                        ),
                        const SizedBox(height: 2),
                        Tooltip(
                          message: previewValue ?? '(vacío)',
                          child: Text(
                            previewValue ?? '(vacío)',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.of(context).foregroundMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: count > 0
                        ? IconButton(
                            tooltip: 'Quitar asignaciones',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => onRemoveFieldAssignments(index),
                          )
                        : null,
                    onTap: () => onFieldSelected(index),
                  ),
                  if (isActive && showParagraphSpanControls)
                    _ParagraphSpanControls(
                      paragraphSpan: currentFieldParagraphSpan,
                      onIncludeNextParagraph: onIncludeNextParagraph,
                      onExcludeLastParagraph: onExcludeLastParagraph,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _ParagraphSpanControls extends StatelessWidget {
  const _ParagraphSpanControls({
    required this.paragraphSpan,
    required this.onIncludeNextParagraph,
    required this.onExcludeLastParagraph,
  });

  final int? paragraphSpan;
  final VoidCallback? onIncludeNextParagraph;
  final VoidCallback? onExcludeLastParagraph;

  @override
  Widget build(BuildContext context) {
    final spansMultiple = (paragraphSpan ?? 1) > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (spansMultiple)
            Text(
              'Este campo abarca $paragraphSpan párrafos',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.of(context).foregroundMuted,
              ),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onIncludeNextParagraph,
                icon: const Icon(Icons.arrow_downward, size: 14),
                label: const Text('Incluir siguiente párrafo'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              if (spansMultiple)
                OutlinedButton.icon(
                  onPressed: onExcludeLastParagraph,
                  icon: const Icon(Icons.arrow_upward, size: 14),
                  label: const Text('Excluir último párrafo'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
