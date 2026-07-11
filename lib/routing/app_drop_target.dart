import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/after_project_load.dart';
import 'package:forkumentos/routing/app_phase_provider.dart';
import 'package:forkumentos/shared/import/dropped_file_kind.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:path/path.dart' as p;

/// Window-level drop target: overlay + import. Cards keep click-to-pick only.
final class AppDropTarget extends ConsumerStatefulWidget {
  const AppDropTarget({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppDropTarget> createState() => _AppDropTargetState();
}

final class _AppDropTargetState extends ConsumerState<AppDropTarget> {
  var _dragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) async {
        setState(() => _dragging = false);
        await _handleDrop(detail.files.map((file) => file.path).toList());
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _dragging ? 1 : 0,
              duration: const Duration(milliseconds: 140),
              child: const _DropOverlay(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDrop(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }

    final classified = <DroppedFileKind, String>{};
    final kindsSeen = <DroppedFileKind>{};
    final unsupportedNames = <String>[];
    for (final path in paths) {
      final kind = classifyDroppedPath(path);
      if (kind == DroppedFileKind.unsupported) {
        unsupportedNames.add(p.basename(path));
        continue;
      }
      kindsSeen.add(kind);
      classified.putIfAbsent(kind, () => path);
    }

    if (classified.isEmpty) {
      final detail = unsupportedNames.isEmpty
          ? 'Usa .docx, .pdf, .csv, .xlsx o .fork.'
          : 'No compatibles: ${unsupportedNames.join(', ')}.';
      _snack('Archivo no compatible. $detail', isError: true);
      return;
    }

    final phase = ref.read(appPhaseProvider);
    final hasProject = ref.read(activeProjectProvider).valueOrNull != null;

    if (classified.containsKey(DroppedFileKind.forkProject)) {
      final forkPath = classified[DroppedFileKind.forkProject]!;
      if (!forkPath.toLowerCase().endsWith(projectFileExtension)) {
        _snack('Selecciona un archivo con extensión .fork.', isError: true);
        return;
      }
      await ref
          .read(activeProjectProvider.notifier)
          .loadProject(filePath: forkPath);
      await afterSuccessfulProjectLoad(ref);
      if (ref.read(activeProjectProvider).hasError) {
        _snack('No se pudo abrir el proyecto.', isError: true);
        return;
      }
      _snack('Proyecto abierto: ${p.basename(forkPath)}');
      return;
    }

    if (!hasProject || phase == AppPhase.landing) {
      _snack(
        'Crea o abre un proyecto antes de importar plantillas o datos.',
        isError: true,
      );
      return;
    }

    final imported = <String>[];

    final templatePath =
        classified[DroppedFileKind.docxTemplate] ??
        classified[DroppedFileKind.pdfTemplate];
    if (templatePath != null) {
      await ref
          .read(activeTemplateProvider.notifier)
          .importTemplate(filePath: templatePath);
      final loaded = ref.read(activeTemplateProvider).valueOrNull?.sourcePath;
      if (loaded != null) {
        ref
            .read(activeProjectProvider.notifier)
            .setEmbeddedArtifactPaths(templatePath: loaded);
        imported.add(labelForDroppedKind(classifyDroppedPath(templatePath)));
      } else if (ref.read(activeTemplateProvider).hasError) {
        _snack('No se pudo importar la plantilla.', isError: true);
        return;
      }
    }

    final datasourcePath =
        classified[DroppedFileKind.csvDatasource] ??
        classified[DroppedFileKind.xlsxDatasource];
    if (datasourcePath != null) {
      await ref
          .read(activeDatasourceProvider.notifier)
          .importDatasource(filePath: datasourcePath);
      final loaded = ref.read(activeDatasourceProvider).valueOrNull?.sourcePath;
      if (loaded != null) {
        ref
            .read(activeProjectProvider.notifier)
            .setEmbeddedArtifactPaths(datasourcePath: loaded);
        imported.add(labelForDroppedKind(classifyDroppedPath(datasourcePath)));
      } else if (ref.read(activeDatasourceProvider).hasError) {
        _snack('No se pudo importar la fuente de datos.', isError: true);
        return;
      }
    }

    if (imported.isEmpty) {
      return;
    }
    // ponytail: overlay shows static type hints; SnackBar reports what landed.
    final extras = kindsSeen.length > imported.length
        ? ' (${kindsSeen.map(labelForDroppedKind).join(' · ')})'
        : '';
    _snack('Importado: ${imported.join(', ')}$extras');
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }
}

final class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.96, end: 1),
          duration: const Duration(milliseconds: 140),
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.file_download_outlined,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Suelta archivos para importar',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Plantilla DOCX · Plantilla PDF · CSV · XLSX',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
