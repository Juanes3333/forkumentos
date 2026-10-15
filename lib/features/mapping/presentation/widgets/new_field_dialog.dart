import 'package:flutter/material.dart';
import 'package:forkumentos/features/mapping/domain/header_remap.dart';

/// Pide el nombre de un campo nuevo (la columna que se agregará al Excel).
/// Devuelve el nombre sin espacios sobrante, o `null` si se cancela. No deja
/// continuar con un nombre vacío ni con uno que ya exista (sin distinguir
/// mayúsculas, tildes ni espacios de más).
Future<String?> showNewFieldDialog(
  BuildContext context, {
  required List<String> existingHeaders,
  String? selectedText,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NewFieldDialog(
      existingHeaders: existingHeaders,
      selectedText: selectedText,
    ),
  );
}

final class _NewFieldDialog extends StatefulWidget {
  const _NewFieldDialog({required this.existingHeaders, this.selectedText});

  final List<String> existingHeaders;
  final String? selectedText;

  @override
  State<_NewFieldDialog> createState() => _NewFieldDialogState();
}

final class _NewFieldDialogState extends State<_NewFieldDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe un nombre para el campo.');
      return;
    }
    final normalized = normalizeHeader(name);
    if (widget.existingHeaders.any(
      (header) => normalizeHeader(header) == normalized,
    )) {
      setState(() => _error = 'Ya existe un campo con ese nombre.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedText?.trim();
    return AlertDialog(
      title: const Text('Crear campo nuevo'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (selected != null && selected.isNotEmpty) ...<Widget>[
              Text('Texto seleccionado: «$selected»'),
              const SizedBox(height: 12),
            ],
            const Text(
              'Se agregará una columna con este nombre al Excel del '
              'proyecto, en el orden del documento.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nombre del campo',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Crear campo')),
      ],
    );
  }
}
