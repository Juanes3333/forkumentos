import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_review.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_navigation_provider.dart';

final class ReviewPanel extends ConsumerWidget {
  const ReviewPanel({
    required this.snapshot,
    required this.headers,
    this.onExport,
    super.key,
  });

  final MappingReviewSnapshot snapshot;
  final List<String> headers;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statistics = snapshot.statistics;
    final navigation = ref.read(mappingNavigationProvider.notifier);

    return Material(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          Text(
            'Revisión de mapeo',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _SummaryCard(snapshot: snapshot),
          const SizedBox(height: 12),
          _StatisticsSection(statistics: statistics),
          const SizedBox(height: 12),
          _ExportReadinessSection(
            isReady: snapshot.isExportReady,
            onExport: snapshot.isExportReady ? onExport : null,
          ),
          const SizedBox(height: 12),
          _IssueSection(
            title: 'Campos sin asignar',
            count: snapshot.missingFieldHeaders.length,
            emptyMessage: 'Todos los campos tienen al menos una asignación.',
            children: <Widget>[
              for (var index = 0; index < headers.length; index++)
                if (snapshot.validation.missingFieldIndexes.contains(index))
                  _NavigationTile(
                    label: headers[index],
                    subtitle: 'Campo pendiente',
                    onTap: () => navigation.navigateTo(
                      DatasourceFieldNavigationTarget(index),
                    ),
                  ),
            ],
          ),
          _IssueSection(
            title: 'Asignaciones duplicadas',
            count: snapshot.duplicateAssignments.length,
            emptyMessage: 'No hay identificadores duplicados.',
            children: <Widget>[
              for (final assignment in snapshot.duplicateAssignments)
                _AssignmentNavigationTile(
                  assignment: assignment,
                  headers: headers,
                  onTap: () => navigation.navigateTo(
                    AssignmentNavigationTarget(assignment.id),
                  ),
                ),
            ],
          ),
          _IssueSection(
            title: 'Asignaciones inválidas',
            count: snapshot.invalidAssignments.length,
            emptyMessage: 'Todas las asignaciones coinciden con el documento.',
            children: <Widget>[
              for (final assignment in snapshot.invalidAssignments)
                _AssignmentNavigationTile(
                  assignment: assignment,
                  headers: headers,
                  onTap: () => navigation.navigateTo(
                    AssignmentNavigationTarget(assignment.id),
                  ),
                ),
            ],
          ),
          _IssueSection(
            title: 'Solapamientos',
            count: snapshot.overlappingAssignmentPairs.length,
            emptyMessage: 'No hay asignaciones solapadas.',
            children: <Widget>[
              for (final pair in snapshot.overlappingAssignmentPairs)
                _NavigationTile(
                  label: _overlapLabel(pair.first, pair.second),
                  subtitle: 'Conflicto entre asignaciones',
                  onTap: () => navigation.navigateTo(
                    AssignmentNavigationTarget(pair.first.id),
                  ),
                ),
            ],
          ),
          _IssueSection(
            title: 'Textos del documento',
            count: snapshot.documentPlaceholders.length,
            emptyMessage: 'No hay texto visible en el documento.',
            children: <Widget>[
              for (final placeholder in snapshot.documentPlaceholders)
                _NavigationTile(
                  label: _truncate(placeholder.text, 48),
                  subtitle: 'Página ${placeholder.path.pageIndex + 1}',
                  onTap: () => navigation.navigateTo(
                    DocumentPlaceholderNavigationTarget(
                      path: placeholder.path,
                      previewText: placeholder.text,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength - 1)}…';
  }

  String _overlapLabel(FieldAssignment first, FieldAssignment second) {
    return '"${first.selectedText}" ↔ "${second.selectedText}"';
  }
}

final class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.snapshot});

  final MappingReviewSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final stats = snapshot.statistics;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Resumen', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              '${stats.mappedFieldCount} de ${stats.totalFields} '
              'campos mapeados',
            ),
            Text('${stats.totalAssignments} asignaciones en total'),
          ],
        ),
      ),
    );
  }
}

final class _StatisticsSection extends StatelessWidget {
  const _StatisticsSection({required this.statistics});

  final MappingStatistics statistics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Estadísticas', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        _StatRow(
          label: 'Campos mapeados',
          value: '${statistics.mappedFieldCount}',
        ),
        _StatRow(
          label: 'Campos pendientes',
          value: '${statistics.pendingFieldCount}',
        ),
        _StatRow(
          label: 'Asignaciones',
          value: '${statistics.totalAssignments}',
        ),
        _StatRow(
          label: 'Faltantes',
          value: '${statistics.missingAssignmentCount}',
        ),
        _StatRow(
          label: 'Duplicadas',
          value: '${statistics.duplicateAssignmentCount}',
        ),
        _StatRow(
          label: 'Inválidas',
          value: '${statistics.invalidAssignmentCount}',
        ),
        _StatRow(label: 'Solapamientos', value: '${statistics.overlapCount}'),
      ],
    );
  }
}

final class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

final class _ExportReadinessSection extends StatelessWidget {
  const _ExportReadinessSection({required this.isReady, this.onExport});

  final bool isReady;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              isReady ? Icons.check_circle_outline : Icons.error_outline,
              size: 18,
              color: isReady ? colorScheme.primary : colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isReady
                    ? 'Listo para exportar'
                    : 'Exportación bloqueada hasta resolver los problemas',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Exportar'),
        ),
      ],
    );
  }
}

final class _IssueSection extends StatelessWidget {
  const _IssueSection({
    required this.title,
    required this.count,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final int count;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$title ($count)', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        if (children.isEmpty)
          Text(emptyMessage, style: Theme.of(context).textTheme.bodySmall)
        else
          ...children,
        const SizedBox(height: 12),
      ],
    );
  }
}

final class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward, size: 16),
      onTap: onTap,
    );
  }
}

final class _AssignmentNavigationTile extends StatelessWidget {
  const _AssignmentNavigationTile({
    required this.assignment,
    required this.headers,
    required this.onTap,
  });

  final FieldAssignment assignment;
  final List<String> headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final header = assignment.fieldIndex < headers.length
        ? headers[assignment.fieldIndex]
        : assignment.fieldHeader;

    return _NavigationTile(
      label: '"${assignment.selectedText}"',
      subtitle: 'Campo: $header · Página ${assignment.path.pageIndex + 1}',
      onTap: onTap,
    );
  }
}
