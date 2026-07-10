import 'package:flutter/material.dart';
import 'package:forkumentos/features/project/domain/project.dart';

final class ProjectToolbar extends StatelessWidget {
  const ProjectToolbar({
    required this.project,
    required this.onSave,
    required this.onOpen,
    required this.onClose,
    required this.isBusy,
    super.key,
    this.onSaveAs,
  });

  final Project project;
  final VoidCallback onSave;
  final VoidCallback? onSaveAs;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final statusText = project.isDirty
        ? 'Proyecto sin guardar'
        : 'Proyecto guardado';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    Tooltip(
                      message: 'Guardar proyecto',
                      child: FilledButton.icon(
                        onPressed: isBusy ? null : onSave,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (onSaveAs != null)
                      Tooltip(
                        message: 'Guardar proyecto en otra ruta',
                        child: OutlinedButton.icon(
                          onPressed: isBusy ? null : onSaveAs,
                          icon: const Icon(Icons.save_as_outlined),
                          label: const Text('Guardar como'),
                        ),
                      ),
                    if (onSaveAs != null) const SizedBox(width: 8),
                    Tooltip(
                      message: 'Abrir proyecto',
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : onOpen,
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Abrir proyecto'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Cerrar proyecto',
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : onClose,
                        icon: const Icon(Icons.close_outlined),
                        label: const Text('Cerrar proyecto'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    project.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    statusText,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
