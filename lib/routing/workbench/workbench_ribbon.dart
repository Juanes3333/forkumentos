import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/domain/mapping_color_palette.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/mapping_workflow_provider.dart';
import 'package:forkumentos/features/preview/presentation/preview_state_provider.dart';
import 'package:forkumentos/features/project/presentation/close_active_project.dart';
import 'package:forkumentos/features/project/presentation/confirm_close_project_dialog.dart';
import 'package:forkumentos/features/project/presentation/create_project_dialog.dart';
import 'package:forkumentos/features/project/presentation/save_active_project.dart';
import 'package:forkumentos/features/settings/presentation/settings_dialog.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/after_project_load.dart';
import 'package:forkumentos/routing/workbench/export_launcher.dart';
import 'package:forkumentos/routing/workbench/workbench_layout_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_resource_actions.dart';
import 'package:forkumentos/routing/workbench/workbench_tab.dart';
import 'package:forkumentos/routing/workbench/workbench_tab_provider.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';
import 'package:forkumentos/shared/widgets/about_forkumentos_dialog.dart';

final class WorkbenchRibbon extends ConsumerWidget {
  const WorkbenchRibbon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final activeTab = ref.watch(workbenchTabProvider);

    return Material(
      color: colors.backgroundSecondary,
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
          Divider(height: 1, thickness: 1, color: colors.border),
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: _RibbonTabContent(tab: activeTab),
            ),
          ),
        ],
      ),
    );
  }
}

final class _RibbonTabContent extends ConsumerWidget {
  const _RibbonTabContent({required this.tab});

  final WorkbenchTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (tab) {
      WorkbenchTab.file => const _FileRibbonActions(),
      WorkbenchTab.home => const _HomeRibbonActions(),
      WorkbenchTab.templates => const _TemplatesRibbonActions(),
      WorkbenchTab.review => const _ReviewRibbonActions(),
      WorkbenchTab.export => const _ExportRibbonActions(),
    };
  }
}

final class _FileRibbonActions extends ConsumerWidget {
  const _FileRibbonActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(activeProjectProvider).valueOrNull;
    final isBusy = ref.watch(activeProjectProvider).isLoading;

    return _RibbonActionsRow(
      children: <Widget>[
        _RibbonGroup(
          label: 'Proyecto',
          children: <Widget>[
            _RibbonActionButton(
              icon: Icons.note_add_outlined,
              label: 'Nuevo proyecto',
              onPressed: isBusy ? null : () => _startNewProject(context, ref),
            ),
            _RibbonActionButton(
              icon: Icons.folder_open_outlined,
              label: 'Abrir proyecto',
              onPressed: isBusy ? null : () => _openProject(context, ref),
            ),
            _RibbonActionButton(
              icon: Icons.save_outlined,
              label: 'Guardar',
              onPressed: project == null || isBusy
                  ? null
                  : () => saveActiveProject(context, ref, project),
            ),
            _RibbonActionButton(
              icon: Icons.save_as_outlined,
              label: 'Guardar como',
              onPressed: project == null || isBusy
                  ? null
                  : () => saveActiveProjectAs(ref, project),
            ),
            _RibbonActionButton(
              icon: Icons.close,
              label: 'Cerrar proyecto',
              onPressed: isBusy ? null : () => closeActiveProject(context, ref),
            ),
          ],
        ),
        _RibbonGroup(
          label: 'Aplicación',
          children: <Widget>[
            _RibbonActionButton(
              icon: Icons.settings_outlined,
              label: 'Configuración',
              onPressed: () => showSettingsDialog(context),
            ),
            _RibbonActionButton(
              icon: Icons.info_outline,
              label: 'Acerca de',
              onPressed: () => showAboutForkumentosDialog(context),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _startNewProject(BuildContext context, WidgetRef ref) async {
  final closed = await closeActiveProject(context, ref);
  if (!closed || !context.mounted) {
    return;
  }

  final projectName = await showCreateProjectDialog(context, ref);
  if (projectName == null || !context.mounted) {
    return;
  }

  await ref
      .read(activeProjectProvider.notifier)
      .createProject(name: projectName);
}

Future<void> _openProject(BuildContext context, WidgetRef ref) async {
  final project = ref.read(activeProjectProvider).valueOrNull;
  if (project != null &&
      project.isDirty &&
      ref.read(confirmBeforeClosingProvider)) {
    if (!context.mounted) {
      return;
    }
    final choice = await confirmCloseProject(context);
    switch (choice) {
      case CloseProjectChoice.cancel:
        return;
      case CloseProjectChoice.closeWithoutSaving:
        break;
      case CloseProjectChoice.saveAndClose:
        if (!context.mounted) {
          return;
        }
        final saved = await saveActiveProject(context, ref, project);
        if (!saved) {
          return;
        }
    }
  }

  final selected = await FilePicker.platform.pickFiles(
    dialogTitle: 'Abrir proyecto',
    type: FileType.custom,
    allowedExtensions: const <String>['fork'],
  );
  final filePath = selected?.files.single.path;
  if (filePath == null) {
    return;
  }

  if (!filePath.toLowerCase().endsWith(projectFileExtension)) {
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Archivo no compatible'),
          content: const Text('Selecciona un archivo con extensión .fork.'),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
    return;
  }

  await ref
      .read(activeProjectProvider.notifier)
      .loadProject(filePath: filePath);
  await afterSuccessfulProjectLoad(ref);
}

final class _HomeRibbonActions extends ConsumerWidget {
  const _HomeRibbonActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datasource = ref.watch(activeDatasourceProvider).valueOrNull;
    final previewState = ref.watch(previewStateProvider);
    final mappingSession = ref.watch(activeMappingProvider);
    final headers = datasource?.headers ?? const <String>[];
    final fieldIndex = headers.isEmpty
        ? 0
        : mappingSession.state.currentFieldIndex.clamp(0, headers.length - 1);
    final fieldColor = mappingColorForFieldIndex(fieldIndex);
    final fieldName = headers.isEmpty ? 'Sin campo' : headers[fieldIndex];

    return _RibbonActionsRow(
      children: <Widget>[
        _RibbonGroup(
          label: 'Historial',
          children: <Widget>[
            _RibbonActionButton(
              icon: Icons.undo,
              label: 'Deshacer',
              tooltip: 'Deshacer (Ctrl+Z)',
              onPressed: mappingSession.canUndo
                  ? ref.read(activeMappingProvider.notifier).undo
                  : null,
            ),
            _RibbonActionButton(
              icon: Icons.redo,
              label: 'Rehacer',
              tooltip: 'Rehacer (Ctrl+Y)',
              onPressed: mappingSession.canRedo
                  ? ref.read(activeMappingProvider.notifier).redo
                  : null,
            ),
          ],
        ),
        VerticalDivider(
          width: 8,
          thickness: 1,
          color: AppColors.of(context).border,
        ),
        _RibbonGroup(
          label: 'Navegación',
          children: <Widget>[
            _RibbonActionButton(
              icon: Icons.navigate_before,
              label: 'Fila anterior',
              onPressed: datasource == null || previewState.rowIndex == 0
                  ? null
                  : ref.read(previewStateProvider.notifier).previousRow,
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                datasource == null
                    ? 'Fila 0/0'
                    : 'Fila ${previewState.rowIndex + 1}/'
                          '${datasource.rowCount}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            _RibbonActionButton(
              icon: Icons.navigate_next,
              label: 'Fila siguiente',
              onPressed: datasource == null
                  ? null
                  : () {
                      ref
                          .read(previewStateProvider.notifier)
                          .nextRow(datasource.rowCount);
                    },
            ),
            _RibbonActionButton(
              icon: Icons.refresh,
              label: 'Actualizar preview',
              isBusy: previewState.isRefreshing,
              onPressed: datasource == null || previewState.isRefreshing
                  ? null
                  : () async {
                      await ref.read(previewStateProvider.notifier).refresh();
                      ref
                              .read(workbenchReviewRenderModeProvider.notifier)
                              .mode =
                          WorkbenchReviewRenderMode.preview;
                    },
            ),
          ],
        ),
        VerticalDivider(
          width: 8,
          thickness: 1,
          color: AppColors.of(context).border,
        ),
        _RibbonGroup(
          label: 'Campo activo',
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: fieldColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      fieldName,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.of(context).foregroundPrimary,
                        decoration: TextDecoration.underline,
                        decorationColor: fieldColor,
                        decorationThickness: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final class _TemplatesRibbonActions extends ConsumerWidget {
  const _TemplatesRibbonActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateState = ref.watch(activeTemplateProvider);
    final template = templateState.valueOrNull;
    final datasourceState = ref.watch(activeDatasourceProvider);
    final datasource = datasourceState.valueOrNull;

    return _RibbonActionsRow(
      children: <Widget>[
        _RibbonGroup(
          label: 'Documento',
          children: <Widget>[
            _RibbonActionButton(
              icon: Icons.description_outlined,
              label: 'Reemplazar plantilla',
              onPressed: templateState.isLoading
                  ? null
                  : () => _replaceTemplate(ref),
            ),
            _RibbonActionButton(
              icon: Icons.file_download_outlined,
              label: 'Exportar plantilla actual',
              onPressed: template == null || templateState.isLoading
                  ? null
                  : () => exportResourceByCopy(
                      context: context,
                      sourcePath: template.sourcePath,
                      dialogTitle: 'Exportar plantilla',
                      suggestedFileName: template.fileName,
                      allowedExtensions: <String>[
                        if (template.sourcePath.toLowerCase().endsWith('.pdf'))
                          'pdf'
                        else
                          'docx',
                      ],
                    ),
            ),
          ],
        ),
        VerticalDivider(
          width: 8,
          thickness: 1,
          color: AppColors.of(context).border,
        ),
        _RibbonGroup(
          label: 'Datos',
          children: <Widget>[
            _RibbonActionButton(
              icon: Icons.table_chart_outlined,
              label: 'Reemplazar datos',
              onPressed: datasourceState.isLoading
                  ? null
                  : () => _replaceDatasource(ref),
            ),
            _RibbonActionButton(
              icon: Icons.file_download_outlined,
              label: 'Exportar datos',
              onPressed: datasource == null || datasourceState.isLoading
                  ? null
                  : () => exportResourceByCopy(
                      context: context,
                      sourcePath: datasource.sourcePath,
                      dialogTitle: 'Exportar datos',
                      suggestedFileName: datasource.fileName,
                      allowedExtensions: <String>[
                        if (datasource.format == DatasourceFormat.csv)
                          'csv'
                        else
                          'xlsx',
                      ],
                    ),
            ),
            _RibbonActionButton(
              icon: Icons.info_outline,
              label: 'Información de la fuente',
              onPressed: datasource == null
                  ? null
                  : () => _showDatasourceInfo(context, datasource),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _replaceTemplate(WidgetRef ref) async {
  final selected = await FilePicker.platform.pickFiles(
    dialogTitle: 'Seleccionar plantilla DOCX o PDF',
    type: FileType.custom,
    allowedExtensions: const <String>['docx', 'pdf'],
  );
  final filePath = selected?.files.single.path;
  if (filePath == null) {
    return;
  }

  await ref
      .read(activeTemplateProvider.notifier)
      .importTemplate(filePath: filePath);
  final path = ref.read(activeTemplateProvider).valueOrNull?.sourcePath;
  if (path != null) {
    ref
        .read(activeProjectProvider.notifier)
        .setEmbeddedArtifactPaths(templatePath: path);
  }
}

Future<void> _replaceDatasource(WidgetRef ref) async {
  final selected = await FilePicker.platform.pickFiles(
    dialogTitle: 'Seleccionar fuente de datos',
    type: FileType.custom,
    allowedExtensions: const <String>['csv', 'xlsx'],
  );
  final filePath = selected?.files.single.path;
  if (filePath == null) {
    return;
  }

  await ref
      .read(activeDatasourceProvider.notifier)
      .importDatasource(filePath: filePath);
  final path = ref.read(activeDatasourceProvider).valueOrNull?.sourcePath;
  if (path != null) {
    ref
        .read(activeProjectProvider.notifier)
        .setEmbeddedArtifactPaths(datasourcePath: path);
  }
}

Future<void> _showDatasourceInfo(BuildContext context, Datasource datasource) {
  final formatLabel = switch (datasource.format) {
    DatasourceFormat.csv => 'CSV',
    DatasourceFormat.xlsx => 'XLSX',
  };

  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Información de la fuente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Archivo: ${datasource.fileName}'),
            const SizedBox(height: 8),
            Text('Formato: $formatLabel'),
            const SizedBox(height: 8),
            Text('Filas: ${datasource.rowCount}'),
            const SizedBox(height: 8),
            SelectableText('Ruta: ${datasource.sourcePath}'),
          ],
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
    },
  );
}

final class _ReviewRibbonActions extends ConsumerWidget {
  const _ReviewRibbonActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(workbenchReviewRenderModeProvider);

    return _RibbonActionsRow(
      children: <Widget>[
        _RibbonGroup(
          label: 'Modo de revisión',
          children: <Widget>[
            ToggleButtons(
              isSelected: <bool>[
                mode == WorkbenchReviewRenderMode.mappingReview,
                mode == WorkbenchReviewRenderMode.preview,
              ],
              onPressed: (index) {
                ref
                    .read(workbenchReviewRenderModeProvider.notifier)
                    .mode = index == 0
                    ? WorkbenchReviewRenderMode.mappingReview
                    : WorkbenchReviewRenderMode.preview;
              },
              borderRadius: BorderRadius.circular(4),
              constraints: const BoxConstraints(minHeight: 32, minWidth: 120),
              children: const <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Revisión de mapeo'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Modo preview'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

final class _ExportRibbonActions extends ConsumerWidget {
  const _ExportRibbonActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final exportReady = ref.watch(exportReadinessProvider);
    final project = ref.watch(activeProjectProvider).valueOrNull;
    final readinessText = exportReady
        ? 'Exportación lista'
        : 'Exportación bloqueada — completa el mapeo y la revisión';

    return _RibbonActionsRow(
      children: <Widget>[
        _RibbonGroup(
          label: 'Exportación',
          children: <Widget>[
            _RibbonActionButton(
              icon: Icons.ios_share_outlined,
              label: 'Exportar',
              onPressed: project == null
                  ? null
                  : () => launchExport(context, ref, pickDestination: false),
            ),
            _RibbonActionButton(
              icon: Icons.drive_folder_upload_outlined,
              label: 'Exportar como',
              onPressed: project == null
                  ? null
                  : () => launchExport(context, ref, pickDestination: true),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  readinessText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: exportReady
                        ? colors.success
                        : colors.foregroundMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final class _RibbonActionsRow extends StatelessWidget {
  const _RibbonActionsRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

final class _RibbonGroup extends StatelessWidget {
  const _RibbonGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.of(context).foregroundMuted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(child: Row(children: children)),
        ],
      ),
    );
  }
}

final class _RibbonActionButton extends StatelessWidget {
  const _RibbonActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.isBusy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final button = TextButton.icon(
      onPressed: onPressed,
      icon: isBusy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.of(context).foregroundPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );

    final message = tooltip;
    if (message == null) {
      return button;
    }

    return Tooltip(message: message, child: button);
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
            ? AppColors.of(context).foregroundPrimary
            : AppColors.of(context).foregroundMuted,
        backgroundColor: isSelected
            ? AppColors.of(context).surface
            : Colors.transparent,
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Text(label),
    );
  }
}
