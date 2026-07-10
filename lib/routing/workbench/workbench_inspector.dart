import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/preview/presentation/preview_state_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_selection_provider.dart';

final class WorkbenchInspector extends ConsumerWidget {
  const WorkbenchInspector({super.key});

  static const double width = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datasource = ref.watch(activeDatasourceProvider).valueOrNull;
    final mappingState = ref.watch(activeMappingProvider).state;
    final previewState = ref.watch(previewStateProvider);
    final previewRow =
        ref.watch(previewRecordProvider).valueOrNull ?? const <String?>[];
    final selection = ref.watch(workbenchSelectionProvider).selection;
    final headers = datasource?.headers ?? const <String>[];
    final currentField = headers.isEmpty
        ? null
        : headers[mappingState.currentFieldIndex.clamp(0, headers.length - 1)];

    return ColoredBox(
      color: AppColors.backgroundSecondary,
      child: SizedBox(
        width: width,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            Text(
              'Inspector · Preview',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Fila activa',
              body: datasource == null
                  ? 'Sin fuente de datos'
                  : 'Fila ${previewState.rowIndex + 1} de '
                        '${datasource.rowCount}',
            ),
            const SizedBox(height: 8),
            _InfoCard(
              title: 'Campo activo',
              body: currentField ?? 'Sin campo activo',
            ),
            const SizedBox(height: 8),
            _InfoCard(
              title: 'Selección',
              body: selection?.selectedText ?? 'Sin selección',
            ),
            if (previewState.errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              _InfoCard(
                title: 'Error',
                body: previewState.errorMessage!,
                isError: true,
              ),
            ],
            if (headers.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _PreviewValuesCard(headers: headers, row: previewRow),
            ],
            const SizedBox(height: 8),
            _InfoCard(
              title: 'Asignaciones',
              body: '${mappingState.assignments.length} región(es) mapeada(s)',
            ),
          ],
        ),
      ),
    );
  }
}

final class _PreviewValuesCard extends StatelessWidget {
  const _PreviewValuesCard({required this.headers, required this.row});

  final List<String> headers;
  final List<String?> row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Valores preview',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < headers.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        headers[index],
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        index < row.length ? (row[index] ?? '—') : '—',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    this.isError = false,
  });

  final String title;
  final String body;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: isError ? colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isError ? colorScheme.onErrorContainer : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
