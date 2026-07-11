import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/workspace/workspace_paths.dart';
import 'package:forkumentos/features/settings/domain/app_settings.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';
import 'package:forkumentos/shared/widgets/forkumentos_logo.dart';

Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => const _SettingsDialog(),
  );
}

final class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog();

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

final class _SettingsDialogState extends ConsumerState<_SettingsDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _workspaceController;
  late final TextEditingController _recentLimitController;
  late final TextEditingController _autosaveController;
  var _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_initialized) {
      _workspaceController.dispose();
      _recentLimitController.dispose();
      _autosaveController.dispose();
    }
    super.dispose();
  }

  void _syncControllers(AppSettings settings) {
    if (!_initialized) {
      _workspaceController = TextEditingController(
        text: settings.workspaceRoot,
      );
      _recentLimitController = TextEditingController(
        text: '${settings.recentProjectsLimit}',
      );
      _autosaveController = TextEditingController(
        text: '${settings.autosaveIntervalSeconds}',
      );
      _initialized = true;
      return;
    }
    if (_workspaceController.text != settings.workspaceRoot) {
      _workspaceController.text = settings.workspaceRoot;
    }
    final limitText = '${settings.recentProjectsLimit}';
    if (_recentLimitController.text != limitText) {
      _recentLimitController.text = limitText;
    }
    final autosaveText = '${settings.autosaveIntervalSeconds}';
    if (_autosaveController.text != autosaveText) {
      _autosaveController.text = autosaveText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull;

    if (settings != null) {
      _syncControllers(settings);
    }

    return AlertDialog(
      title: const Row(
        children: <Widget>[
          ForkumentosLogo(height: 28),
          SizedBox(width: 12),
          Text('Configuración'),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 420,
        child: settings == null || !_initialized
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TabBar(
                    controller: _tabController,
                    tabs: const <Widget>[
                      Tab(text: 'General'),
                      Tab(text: 'Apariencia'),
                      Tab(text: 'Comportamiento'),
                      Tab(text: 'Exportación'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _GeneralTab(
                          settings: settings,
                          workspaceController: _workspaceController,
                          onBrowse: () => _browseWorkspace(context),
                          onApplyRoot: () {
                            ref
                                .read(settingsProvider.notifier)
                                .setWorkspaceRoot(_workspaceController.text);
                          },
                        ),
                        _AppearanceTab(settings: settings),
                        _BehaviorTab(
                          settings: settings,
                          recentLimitController: _recentLimitController,
                          autosaveController: _autosaveController,
                        ),
                        _ExportTab(settings: settings),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: settings == null
              ? null
              : () async {
                  await ref.read(settingsProvider.notifier).restoreDefaults();
                },
          child: const Text('Restaurar valores'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _browseWorkspace(BuildContext context) async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Seleccionar directorio de trabajo',
    );
    if (selected == null || !mounted) {
      return;
    }
    _workspaceController.text = selected;
    await ref.read(settingsProvider.notifier).setWorkspaceRoot(selected);
  }
}

final class _GeneralTab extends StatelessWidget {
  const _GeneralTab({
    required this.settings,
    required this.workspaceController,
    required this.onBrowse,
    required this.onApplyRoot,
  });

  final AppSettings settings;
  final TextEditingController workspaceController;
  final VoidCallback onBrowse;
  final VoidCallback onApplyRoot;

  @override
  Widget build(BuildContext context) {
    final paths = WorkspacePaths(root: settings.workspaceRoot);
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return ListView(
      children: <Widget>[
        Text(
          'Directorio de trabajo',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: workspaceController,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Ruta del workspace',
                ),
                onSubmitted: (_) => onApplyRoot(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onBrowse, child: const Text('Examinar')),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: onApplyRoot,
            child: const Text('Aplicar ruta'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Rutas derivadas', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text('Proyectos: ${paths.projects}', style: muted),
        const SizedBox(height: 4),
        Text('Exportaciones: ${paths.exports}', style: muted),
        const SizedBox(height: 8),
        Text(
          'Estas carpetas se crean bajo el directorio de trabajo. '
          'No son raíces independientes.',
          style: muted,
        ),
      ],
    );
  }
}

final class _AppearanceTab extends ConsumerWidget {
  const _AppearanceTab({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: <Widget>[
        Text('Tema', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<AppThemePreference>(
          segments: const <ButtonSegment<AppThemePreference>>[
            ButtonSegment<AppThemePreference>(
              value: AppThemePreference.dark,
              label: Text('Oscuro'),
              icon: Icon(Icons.dark_mode_outlined),
            ),
            ButtonSegment<AppThemePreference>(
              value: AppThemePreference.light,
              label: Text('Claro'),
              icon: Icon(Icons.light_mode_outlined),
            ),
            ButtonSegment<AppThemePreference>(
              value: AppThemePreference.system,
              label: Text('Sistema'),
              icon: Icon(Icons.brightness_auto_outlined),
            ),
          ],
          selected: <AppThemePreference>{settings.theme},
          onSelectionChanged: (selected) {
            ref.read(settingsProvider.notifier).setTheme(selected.first);
          },
        ),
      ],
    );
  }
}

final class _BehaviorTab extends ConsumerWidget {
  const _BehaviorTab({
    required this.settings,
    required this.recentLimitController,
    required this.autosaveController,
  });

  final AppSettings settings;
  final TextEditingController recentLimitController;
  final TextEditingController autosaveController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Abrir el más reciente al iniciar'),
          subtitle: Text(
            'Si hay historial, abre el primer proyecto al llegar a Inicio.',
            style: muted,
          ),
          value: settings.openRecentOnStartup,
          onChanged: (value) {
            notifier.setOpenRecentOnStartup(value: value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Límite de proyectos recientes',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: recentLimitController,
          decoration: const InputDecoration(isDense: true, hintText: '1–50'),
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          onSubmitted: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null) {
              notifier.setRecentProjectsLimit(parsed);
            }
          },
          onEditingComplete: () {
            final parsed = int.tryParse(recentLimitController.text);
            if (parsed != null) {
              notifier.setRecentProjectsLimit(parsed);
            }
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Confirmar antes de cerrar'),
          subtitle: Text(
            'Activado: pide confirmación si hay cambios sin guardar. '
            'Desactivado: cierra sin preguntar, aunque haya cambios.',
            style: muted,
          ),
          value: settings.confirmBeforeClosing,
          onChanged: (value) {
            notifier.setConfirmBeforeClosing(value: value);
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Intervalo de autoguardado (segundos)',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: autosaveController,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '0 = desactivado',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          onSubmitted: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null) {
              notifier.setAutosaveIntervalSeconds(parsed);
            }
          },
          onEditingComplete: () {
            final parsed = int.tryParse(autosaveController.text);
            if (parsed != null) {
              notifier.setAutosaveIntervalSeconds(parsed);
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Reservado: el valor se guarda, pero el autoguardado '
          'automático aún no está activo.',
          style: muted,
        ),
      ],
    );
  }
}

final class _ExportTab extends ConsumerWidget {
  const _ExportTab({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      children: <Widget>[
        Text(
          'Formato de exportación por defecto',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const <ButtonSegment<String>>[
            ButtonSegment<String>(
              value: ExportFormatSetting.docx,
              label: Text('DOCX'),
            ),
            ButtonSegment<String>(
              value: ExportFormatSetting.pdf,
              label: Text('PDF'),
            ),
            ButtonSegment<String>(
              value: ExportFormatSetting.both,
              label: Text('Ambos'),
            ),
          ],
          selected: <String>{settings.defaultExportFormat},
          onSelectionChanged: (selected) {
            notifier.setDefaultExportFormat(selected.first);
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Crear ZIP por defecto'),
          value: settings.defaultCreateZip,
          onChanged: (value) {
            notifier.setDefaultCreateZip(value: value);
          },
        ),
      ],
    );
  }
}
