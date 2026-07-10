import 'package:flutter/material.dart';

final class FloatingMappingMenu extends StatelessWidget {
  const FloatingMappingMenu({
    required this.fieldName,
    required this.onConfirm,
    required this.onReject,
    super.key,
  });

  final String fieldName;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Este texto representa el campo:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(fieldName, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '¿Es correcto?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(onPressed: onReject, child: const Text('No')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: onConfirm, child: const Text('Sí')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
