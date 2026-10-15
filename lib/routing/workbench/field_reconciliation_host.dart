import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/mapping/domain/field_reconciliation.dart';
import 'package:forkumentos/features/mapping/presentation/field_reconciliation_provider.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/field_reconciliation_dialog.dart';

/// Abre el diálogo de reconciliación cuando aparecen campos sin columna que
/// el usuario aún no ha visto (al reemplazar o refrescar el Excel, cuando el
/// observer detecta un guardado y al abrir un proyecto cuyo Excel cambió).
final class FieldReconciliationHost extends ConsumerStatefulWidget {
  const FieldReconciliationHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FieldReconciliationHost> createState() =>
      _FieldReconciliationHostState();
}

final class _FieldReconciliationHostState
    extends ConsumerState<FieldReconciliationHost> {
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    // Un proyecto puede abrirse ya con campos sin columna.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeShow(ref.read(fieldReconciliationProvider));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<FieldReconciliationItem>>(
      fieldReconciliationProvider,
      (previous, next) => _maybeShow(next),
    );
    return widget.child;
  }

  Future<void> _maybeShow(List<FieldReconciliationItem> items) async {
    final current = <String>{for (final item in items) item.orphanHeader};
    var dismissed = ref.read(dismissedOrphanHeadersProvider);
    // Un campo resuelto que más tarde vuelve a quedar sin columna es un
    // aviso nuevo: se olvida lo visto que ya no está pendiente.
    if (!dismissed.every(current.contains)) {
      dismissed = dismissed.intersection(current);
      ref.read(dismissedOrphanHeadersProvider.notifier).state = dismissed;
    }
    final hasUnseen = current.any((header) => !dismissed.contains(header));
    if (!hasUnseen || _dialogOpen) {
      return;
    }
    _dialogOpen = true;
    await showFieldReconciliationDialog(context);
    _dialogOpen = false;
  }
}
