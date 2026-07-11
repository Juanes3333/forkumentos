import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/settings/domain/app_settings.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';

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

final class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  late final TextEditingController _workspaceController;
  var _initialized = false;

  @override
  void dispose() {
    if (_initialized) {
      _workspaceController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull;

    if (settings != null && !_initialized) {
      _workspaceController = TextEditingController(
        text: settings.workspaceRoot,
      );
      _initialized = true;
    }

    return AlertDialog(
      title: const Text('Configuración'),
      content: SizedBox(
        width: 480,
        child: settings == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          controller: _workspaceController,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Ruta del workspace',
                          ),
                          onSubmitted: (value) {
                            ref
                                .read(settingsProvider.notifier)
                                .setWorkspaceRoot(value);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _browseWorkspace(context),
                        child: const Text('Examinar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: () {
                        ref
                            .read(settingsProvider.notifier)
                            .setWorkspaceRoot(_workspaceController.text);
                      },
                      child: const Text('Aplicar ruta'),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                    ],
                    selected: <AppThemePreference>{settings.theme},
                    onSelectionChanged: (selected) {
                      final theme = selected.first;
                      ref.read(settingsProvider.notifier).setTheme(theme);
                    },
                  ),
                ],
              ),
      ),
      actions: <Widget>[
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
