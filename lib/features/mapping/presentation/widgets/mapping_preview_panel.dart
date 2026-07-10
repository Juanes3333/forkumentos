import 'package:flutter/material.dart';
import 'package:forkumentos/features/mapping/domain/mapping_color_palette.dart';
import 'package:forkumentos/features/mapping/domain/mapping_field_status.dart';

final class MappingPreviewPanel extends StatelessWidget {
  const MappingPreviewPanel({
    required this.headers,
    required this.previewRow,
    required this.currentFieldIndex,
    required this.assignmentCounts,
    super.key,
  });

  final List<String> headers;
  final List<String?> previewRow;
  final int currentFieldIndex;
  final List<int> assignmentCounts;

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return const SizedBox.shrink();
    }

    final mappedCount = assignmentCounts.where((count) => count > 0).length;

    return Material(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Vista previa de la primera fila',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  'Progreso: $mappedCount de ${headers.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (var index = 0; index < headers.length; index++)
                    _PreviewFieldChip(
                      header: headers[index],
                      previewValue: index < previewRow.length
                          ? previewRow[index]
                          : null,
                      color: mappingColorForFieldIndex(index),
                      isActive: index == currentFieldIndex,
                      status: _statusFor(index),
                      assignmentCount: assignmentCounts[index],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  MappingFieldStatus _statusFor(int index) {
    if (assignmentCounts[index] > 0) {
      return MappingFieldStatus.assigned;
    }
    return MappingFieldStatus.pending;
  }
}

final class _PreviewFieldChip extends StatelessWidget {
  const _PreviewFieldChip({
    required this.header,
    required this.previewValue,
    required this.color,
    required this.isActive,
    required this.status,
    required this.assignmentCount,
  });

  final String header;
  final String? previewValue;
  final Color color;
  final bool isActive;
  final MappingFieldStatus status;
  final int assignmentCount;

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive ? color : Theme.of(context).dividerColor;

    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: isActive ? 0.12 : 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  header,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            previewValue ?? '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            status == MappingFieldStatus.assigned
                ? 'Asignado ($assignmentCount)'
                : 'Pendiente',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
