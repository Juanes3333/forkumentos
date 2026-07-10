import 'package:flutter/material.dart';
import 'package:forkumentos/features/mapping/domain/mapping_color_palette.dart';
import 'package:forkumentos/features/mapping/domain/mapping_field_status.dart';

final class MappingFieldSidebar extends StatelessWidget {
  const MappingFieldSidebar({
    required this.headers,
    required this.currentFieldIndex,
    required this.assignmentCounts,
    required this.onFieldSelected,
    required this.onFieldHoverChanged,
    required this.onRemoveFieldAssignments,
    super.key,
  });

  final List<String> headers;
  final int currentFieldIndex;
  final List<int> assignmentCounts;
  final ValueChanged<int> onFieldSelected;
  final ValueChanged<int?> onFieldHoverChanged;
  final ValueChanged<int> onRemoveFieldAssignments;

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

            return MouseRegion(
              onEnter: (_) => onFieldHoverChanged(index),
              onExit: (_) => onFieldHoverChanged(null),
              child: ListTile(
                selected: isActive,
                leading: Icon(Icons.circle, size: 12, color: color),
                title: Text(headers[index]),
                subtitle: Text(
                  status == MappingFieldStatus.assigned
                      ? '$count asignación${count == 1 ? '' : 'es'}'
                      : 'Pendiente',
                ),
                trailing: count > 0
                    ? IconButton(
                        tooltip: 'Quitar asignaciones',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onRemoveFieldAssignments(index),
                      )
                    : null,
                onTap: () => onFieldSelected(index),
              ),
            );
          },
        ),
      ),
    );
  }
}
