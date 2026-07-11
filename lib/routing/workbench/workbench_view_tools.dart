import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_controller_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_layout_provider.dart';

/// Persistent zoom / fit / inspector tools shown on every ribbon tab.
final class WorkbenchViewTools extends ConsumerWidget {
  const WorkbenchViewTools({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(documentViewerControllerProvider);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const VerticalDivider(
              width: 16,
              thickness: 1,
              color: AppColors.border,
            ),
            _ViewToolGroup(
              label: 'Zoom',
              children: <Widget>[
                IconButton(
                  tooltip: 'Alejar',
                  onPressed: controller.isAttached ? controller.zoomOut : null,
                  icon: const Icon(Icons.remove, size: 18),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${controller.zoomPercentage}%',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.foregroundPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Acercar',
                  onPressed: controller.isAttached ? controller.zoomIn : null,
                  icon: const Icon(Icons.add, size: 18),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            _ViewToolGroup(
              label: 'Ajuste',
              children: <Widget>[
                _CompactToolButton(
                  tooltip: 'Ajustar a página',
                  label: 'Página',
                  icon: Icons.fit_screen_outlined,
                  isActive: controller.isFitPage,
                  onPressed: controller.isAttached ? controller.fitPage : null,
                ),
                _CompactToolButton(
                  tooltip: 'Ajustar al ancho',
                  label: 'Ancho',
                  icon: Icons.width_normal_outlined,
                  isActive: controller.isFitWidth,
                  onPressed: controller.isAttached ? controller.fitWidth : null,
                ),
              ],
            ),
            const SizedBox(width: 4),
            _ViewToolGroup(
              label: 'Panel',
              children: <Widget>[
                _CompactToolButton(
                  tooltip: 'Mostrar u ocultar panel derecho',
                  label: 'Inspector',
                  icon: Icons.view_sidebar_outlined,
                  isActive: ref.watch(workbenchInspectorVisibleProvider),
                  onPressed: () {
                    ref
                        .read(workbenchInspectorVisibleProvider.notifier)
                        .toggle();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

final class _ViewToolGroup extends StatelessWidget {
  const _ViewToolGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.foregroundMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: children),
      ],
    );
  }
}

final class _CompactToolButton extends StatelessWidget {
  const _CompactToolButton({
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: isActive
              ? AppColors.accent
              : AppColors.foregroundPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
