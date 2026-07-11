import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_navigation_provider.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/mapping_review_sidebar.dart';
import 'package:forkumentos/features/preview/presentation/preview_state_provider.dart';

final class WorkbenchInspector extends ConsumerWidget {
  const WorkbenchInspector({super.key});

  static const double width = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datasource = ref.watch(activeDatasourceProvider).valueOrNull;
    final mappingState = ref.watch(activeMappingProvider).state;
    final previewState = ref.watch(previewStateProvider);
    final headers = datasource?.headers ?? const <String>[];

    return ColoredBox(
      color: AppColors.backgroundSecondary,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Campos',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.foregroundPrimary,
                    ),
                  ),
                  if (datasource != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      'Fila ${previewState.rowIndex + 1} de '
                      '${datasource.rowCount}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.foregroundMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Expanded(
              child: headers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Importa una fuente de datos desde la pestaña '
                        'Plantillas para ver los campos aquí.',
                        style: TextStyle(color: AppColors.foregroundMuted),
                      ),
                    )
                  : MappingReviewSidebar(
                      headers: headers,
                      assignments: mappingState.assignments,
                      onRemoveAssignment: (assignmentId) {
                        ref
                            .read(activeMappingProvider.notifier)
                            .removeAssignment(assignmentId);
                      },
                      onNavigateToAssignment: (assignmentId) {
                        ref
                            .read(mappingNavigationProvider.notifier)
                            .navigateTo(
                              AssignmentNavigationTarget(assignmentId),
                            );
                      },
                      onNavigateToField: (fieldIndex) {
                        ref
                            .read(activeMappingProvider.notifier)
                            .setCurrentFieldIndex(fieldIndex);
                        ref
                            .read(mappingNavigationProvider.notifier)
                            .navigateTo(
                              DatasourceFieldNavigationTarget(fieldIndex),
                            );
                      },
                      onFieldHoverChanged: (fieldIndex) {
                        ref
                            .read(activeMappingProvider.notifier)
                            .setHoveredFieldIndex(fieldIndex);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
