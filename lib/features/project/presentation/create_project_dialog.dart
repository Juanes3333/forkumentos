import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';

/// Prompts for a project name. Empty input resolves to the next automatic
/// "Proyecto N" name. Returns `null` if cancelled.
Future<String?> showCreateProjectDialog(BuildContext context, WidgetRef ref) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return _CreateProjectDialog(ref: ref);
    },
  );
}

final class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

final class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final TextEditingController _controller = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    setState(() => _submitting = true);

    var name = _controller.text.trim();
    if (name.isEmpty) {
      final paths = widget.ref.read(workspacePathsProvider);
      if (paths == null) {
        setState(() => _submitting = false);
        return;
      }
      name = await paths.nextAutomaticProjectName();
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear proyecto'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Nombre del proyecto',
          hintText: 'Vacío = Proyecto automático',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }
}
