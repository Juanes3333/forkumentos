import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/presentation/datasource_sync_controller.dart';

/// Muestra en una SnackBar los avisos de sincronización con el Excel (datos
/// actualizados por el observer o al abrir el proyecto, Excel movido a la
/// carpeta gestionada) y los da por vistos.
final class DatasourceSyncHost extends ConsumerWidget {
  const DatasourceSyncHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(datasourceSyncMessageProvider, (previous, message) {
      if (message == null) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      ref.read(datasourceSyncMessageProvider.notifier).state = null;
    });
    return child;
  }
}
