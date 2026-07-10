import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/preview/presentation/preview_state_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_mapping_actions.dart';
import 'package:forkumentos/routing/workbench/workbench_selection_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_tab.dart';
import 'package:forkumentos/routing/workbench/workbench_tab_provider.dart';

final class WorkbenchRibbon extends ConsumerWidget {
  const WorkbenchRibbon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(workbenchTabProvider);
    final datasource = ref.watch(activeDatasourceProvider).valueOrNull;
    final previewState = ref.watch(previewStateProvider);
    final mappingSession = ref.watch(activeMappingProvider);
    final headers = datasource?.headers ?? const <String>[];
    final selectionState = ref.watch(workbenchSelectionProvider);

    return Material(
      color: AppColors.backgroundSecondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 36,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final tab in WorkbenchTab.values)
                    _RibbonTabButton(
                      label: tab.label,
                      isSelected: tab == activeTab,
                      onPressed: () {
                        ref.read(workbenchTabProvider.notifier).selectTab(tab);
                      },
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  _ribbonHint(activeTab),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.foregroundMuted,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: datasource == null || previewState.rowIndex == 0
                      ? null
                      : ref.read(previewStateProvider.notifier).previousRow,
                  icon: const Icon(Icons.navigate_before),
                  label: const Text('Fila anterior'),
                ),
                OutlinedButton.icon(
                  onPressed: datasource == null
                      ? null
                      : () {
                          ref
                              .read(previewStateProvider.notifier)
                              .nextRow(datasource.rowCount);
                        },
                  icon: const Icon(Icons.navigate_next),
                  label: const Text('Fila siguiente'),
                ),
                Chip(
                  label: Text(
                    datasource == null
                        ? 'Fila 0/0'
                        : 'Fila ${previewState.rowIndex + 1}/${datasource.rowCount}',
                  ),
                ),
                FilledButton.icon(
                  onPressed: datasource == null || previewState.isRefreshing
                      ? null
                      : () {
                          ref.read(previewStateProvider.notifier).refresh();
                        },
                  icon: previewState.isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Actualizar preview'),
                ),
                const VerticalDivider(width: 1),
                if (headers.isNotEmpty)
                  DropdownButton<int>(
                    value: mappingSession.state.currentFieldIndex.clamp(
                      0,
                      headers.length - 1,
                    ),
                    hint: const Text('Campo'),
                    items: <DropdownMenuItem<int>>[
                      for (var index = 0; index < headers.length; index++)
                        DropdownMenuItem<int>(
                          value: index,
                          child: Text(headers[index]),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      ref
                          .read(activeMappingProvider.notifier)
                          .setCurrentFieldIndex(value);
                    },
                  ),
                Tooltip(
                  message: 'Asigna la selección al campo activo',
                  child: FilledButton.icon(
                    onPressed: !selectionState.hasSelection || headers.isEmpty
                        ? null
                        : () => assignWorkbenchSelection(context, ref),
                    icon: const Icon(Icons.link_outlined),
                    label: const Text('Asignar selección'),
                  ),
                ),
                Tooltip(
                  message: 'Deshacer (Ctrl+Z)',
                  child: OutlinedButton.icon(
                    onPressed: mappingSession.canUndo
                        ? ref.read(activeMappingProvider.notifier).undo
                        : null,
                    icon: const Icon(Icons.undo),
                    label: const Text('Deshacer'),
                  ),
                ),
                Tooltip(
                  message: 'Rehacer (Ctrl+Y)',
                  child: OutlinedButton.icon(
                    onPressed: mappingSession.canRedo
                        ? ref.read(activeMappingProvider.notifier).redo
                        : null,
                    icon: const Icon(Icons.redo),
                    label: const Text('Rehacer'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ribbonHint(WorkbenchTab tab) {
    return switch (tab) {
      WorkbenchTab.file => 'Archivo',
      WorkbenchTab.home => 'Inicio',
      WorkbenchTab.template => 'Plantilla',
      WorkbenchTab.datasource => 'Datos',
      WorkbenchTab.mapping => 'Mapeo',
      WorkbenchTab.review => 'Revisión',
      WorkbenchTab.export => 'Exportar',
      WorkbenchTab.view => 'Vista',
      WorkbenchTab.help => 'Ayuda',
    };
  }
}

final class _RibbonTabButton extends StatelessWidget {
  const _RibbonTabButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isSelected
            ? AppColors.foregroundPrimary
            : AppColors.foregroundMuted,
        backgroundColor: isSelected ? AppColors.surface : Colors.transparent,
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Text(label),
    );
  }
}
