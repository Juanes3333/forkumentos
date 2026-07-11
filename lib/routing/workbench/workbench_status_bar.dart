import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_controller.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_controller_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_mode.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/routing/workbench/workbench_layout_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_tab.dart';
import 'package:forkumentos/routing/workbench/workbench_tab_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';

final class WorkbenchStatusBar extends ConsumerWidget {
  const WorkbenchStatusBar({super.key});

  static const double height = 26;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final project = ref.watch(activeProjectProvider).valueOrNull;
    final tab = ref.watch(workbenchTabProvider);
    final exportReady = ref.watch(exportReadinessProvider);
    final workflowMode = ref.watch(mappingWorkflowProvider).mode;
    final controller = ref.watch(documentViewerControllerProvider);
    final inspectorVisible = ref.watch(workbenchInspectorVisibleProvider);

    final statusText = _resolveStatusText(
      project: project,
      tab: tab,
      workflowMode: workflowMode,
      exportReady: exportReady,
    );

    return SizedBox(
      height: height,
      child: Material(
        color: colors.backgroundSecondary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.foregroundMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  return _StatusZoomControls(
                    controller: controller,
                    inspectorVisible: inspectorVisible,
                    onToggleInspector: () {
                      ref
                          .read(workbenchInspectorVisibleProvider.notifier)
                          .toggle();
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _StatusZoomControls extends StatelessWidget {
  const _StatusZoomControls({
    required this.controller,
    required this.inspectorVisible,
    required this.onToggleInspector,
  });

  final DocumentViewerController controller;
  final bool inspectorVisible;
  final VoidCallback onToggleInspector;

  static const double _minScale = 0.5;
  static const double _maxScale = 2;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final attached = controller.isAttached;
    final zoomPct = controller.zoomPercentage;
    final sliderValue = (zoomPct / 100).clamp(_minScale, _maxScale);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StatusIconButton(
          tooltip: 'Alejar',
          icon: Icons.remove,
          onPressed: attached ? controller.zoomOut : null,
        ),
        SizedBox(
          width: 100,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: sliderValue,
              min: _minScale,
              max: _maxScale,
              onChanged: attached ? controller.setScale : null,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$zoomPct%',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.foregroundPrimary,
              fontSize: 11,
            ),
          ),
        ),
        _StatusIconButton(
          tooltip: 'Acercar',
          icon: Icons.add,
          onPressed: attached ? controller.zoomIn : null,
        ),
        const SizedBox(width: 4),
        _StatusIconButton(
          tooltip: 'Ajustar a página',
          icon: Icons.fit_screen_outlined,
          isActive: controller.isFitPage,
          onPressed: attached ? controller.fitPage : null,
        ),
        _StatusIconButton(
          tooltip: 'Ajustar al ancho',
          icon: Icons.width_normal_outlined,
          isActive: controller.isFitWidth,
          onPressed: attached ? controller.fitWidth : null,
        ),
        const SizedBox(width: 4),
        _StatusIconButton(
          tooltip: 'Mostrar u ocultar panel derecho',
          icon: Icons.view_sidebar_outlined,
          isActive: inspectorVisible,
          onPressed: onToggleInspector,
        ),
      ],
    );
  }
}

final class _StatusIconButton extends StatelessWidget {
  const _StatusIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      color: isActive ? colors.accent : colors.foregroundPrimary,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
    );
  }
}

String _resolveStatusText({
  required Project? project,
  required WorkbenchTab tab,
  required MappingWorkflowMode workflowMode,
  required bool exportReady,
}) {
  if (project == null) {
    return 'Sin proyecto activo';
  }

  final dirtySuffix = project.isDirty ? ' · Sin guardar' : '';
  final tabLabel = tab.label;

  if (tab == WorkbenchTab.review ||
      workflowMode == MappingWorkflowMode.review) {
    final readiness = exportReady ? 'lista' : 'bloqueada';
    return '${project.name} · $tabLabel · Exportación: $readiness'
        '$dirtySuffix';
  }

  return '${project.name} · $tabLabel$dirtySuffix';
}
