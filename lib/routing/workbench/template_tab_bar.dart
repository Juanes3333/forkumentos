import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/routing/workbench/workbench_selection_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:path/path.dart' as p;

/// Una pestaña de plantilla.
typedef TemplateTabInfo = ({String? id, String fileName, bool isActive});

/// Pestañas de las plantillas Word del proyecto, estilo navegador pero
/// colgando del ribbon: borde superior plano, empalmes cóncavos hacia arriba
/// y esquinas inferiores redondeadas. Con una sola plantilla muestra su
/// pestaña y el "+" para añadir otra.
final templateTabsProvider = Provider<List<TemplateTabInfo>>((ref) {
  final project = ref.watch(activeProjectProvider).valueOrNull;
  if (project == null) {
    return const <TemplateTabInfo>[];
  }
  if (project.templates.isNotEmpty) {
    return <TemplateTabInfo>[
      for (final template in project.templates)
        (
          id: template.id,
          fileName: template.id == project.activeTemplateId
              ? _activeFileName(project.embeddedTemplatePath, template.fileName)
              : template.fileName,
          isActive: template.id == project.activeTemplateId,
        ),
    ];
  }
  final path = project.embeddedTemplatePath;
  if (path == null || path.isEmpty) {
    return const <TemplateTabInfo>[];
  }
  return <TemplateTabInfo>[
    (id: null, fileName: p.basename(path), isActive: true),
  ];
});

String _activeFileName(String? path, String fallback) =>
    path == null ? fallback : p.basename(path);

/// Cambia a la plantilla siguiente (o anterior si [step] es negativo).
void cycleTemplate(WidgetRef ref, int step) {
  final tabs = ref.read(templateTabsProvider);
  if (tabs.length < 2) {
    return;
  }
  final current = tabs.indexWhere((tab) => tab.isActive);
  final next = tabs[(current + step) % tabs.length];
  _select(ref, next.id);
}

void _select(WidgetRef ref, String? id) {
  if (id == null) {
    return;
  }
  // La selección de texto pertenece al documento que se deja.
  ref.read(workbenchSelectionProvider.notifier).clearSelection();
  ref.read(activeProjectProvider.notifier).selectTemplate(id);
}

Future<void> _addTemplate(WidgetRef ref) async {
  final selected = await FilePicker.platform.pickFiles(
    dialogTitle: 'Añadir plantilla DOCX',
    type: FileType.custom,
    allowedExtensions: const <String>['docx'],
  );
  final path = selected?.files.single.path;
  if (path == null) {
    return;
  }
  ref.read(workbenchSelectionProvider.notifier).clearSelection();
  await ref.read(activeProjectProvider.notifier).addTemplate(sourcePath: path);
}

Future<void> _confirmRemove(
  BuildContext context,
  WidgetRef ref,
  TemplateTabInfo tab,
) async {
  final remove = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Quitar plantilla'),
      content: Text(
        '¿Quitar «${tab.fileName}» del proyecto? Se pierde su mapeo; puedes '
        'deshacerlo volviendo a añadir el archivo y mapeándolo de nuevo.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Quitar'),
        ),
      ],
    ),
  );
  if (remove ?? false) {
    ref.read(workbenchSelectionProvider.notifier).clearSelection();
    ref.read(activeProjectProvider.notifier).removeTemplate(tab.id!);
  }
}

final class TemplateTabBar extends ConsumerWidget {
  const TemplateTabBar({super.key});

  static const double height = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(templateTabsProvider);
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = AppColors.of(context);
    final canClose = tabs.length > 1;

    return SizedBox(
      height: height,
      child: ColoredBox(
        color: colors.backgroundPrimary,
        child: Row(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final tab in tabs)
                      _TemplateTab(
                        tab: tab,
                        canClose: canClose,
                        onSelect: () => _select(ref, tab.id),
                        onClose: () => _confirmRemove(context, ref, tab),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Añadir plantilla',
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => _addTemplate(ref),
            ),
          ],
        ),
      ),
    );
  }
}

final class _TemplateTab extends StatelessWidget {
  const _TemplateTab({
    required this.tab,
    required this.canClose,
    required this.onSelect,
    required this.onClose,
  });

  final TemplateTabInfo tab;
  final bool canClose;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  static const double _flare = 8;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = p.basenameWithoutExtension(tab.fileName);
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: tab.isActive ? colors.foregroundPrimary : colors.foregroundMuted,
      fontWeight: tab.isActive ? FontWeight.w600 : FontWeight.w400,
    );

    return Tooltip(
      message: tab.fileName,
      child: CustomPaint(
        painter: _HangingTabPainter(
          color: tab.isActive ? colors.backgroundSecondary : null,
          flare: _flare,
        ),
        child: InkWell(
          onTap: onSelect,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.only(left: _flare + 8, right: _flare),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220, minWidth: 90),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle,
                    ),
                  ),
                  if (canClose)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        tooltip: 'Quitar plantilla',
                        padding: EdgeInsets.zero,
                        iconSize: 14,
                        icon: const Icon(Icons.close),
                        onPressed: onClose,
                      ),
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pestaña "colgante": plana arriba, con empalmes cóncavos hacia el ribbon y
/// esquinas inferiores redondeadas. Sin [color] (pestaña inactiva) no dibuja
/// nada.
final class _HangingTabPainter extends CustomPainter {
  const _HangingTabPainter({required this.color, required this.flare});

  final Color? color;
  final double flare;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = color;
    if (fill == null) {
      return;
    }
    final w = size.width;
    final h = size.height;
    final r = flare;
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(r, 0, r, r)
      ..lineTo(r, h - r)
      ..quadraticBezierTo(r, h, r * 2, h)
      ..lineTo(w - r * 2, h)
      ..quadraticBezierTo(w - r, h, w - r, h - r)
      ..lineTo(w - r, r)
      ..quadraticBezierTo(w - r, 0, w, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_HangingTabPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.flare != flare;
}
