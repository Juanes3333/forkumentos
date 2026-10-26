import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_mapping_actions.dart';
import 'package:forkumentos/routing/workbench/workbench_selection_provider.dart';

/// Word-like floating tooltip for assigning the current text selection.
final class WorkbenchSelectionTooltip extends ConsumerWidget {
  const WorkbenchSelectionTooltip({required this.stackKey, super.key});

  /// Key of the workspace [Stack] used to convert global selection anchors
  /// into local [Positioned] coordinates.
  final GlobalKey stackKey;

  static const double _maxWidth = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final selectionState = ref.watch(workbenchSelectionProvider);
    final selection = selectionState.selection;
    final anchor = selectionState.anchor;
    if (selection == null || anchor == null) {
      return const SizedBox.shrink();
    }

    final datasource = ref.watch(activeDatasourceProvider).valueOrNull;
    final headers = datasource?.headers ?? const <String>[];
    final mappingNotifier = ref.read(activeMappingProvider.notifier);
    final mappingState = ref.watch(activeMappingProvider).state;
    final fieldIndex = headers.isEmpty
        ? 0
        : mappingState.currentFieldIndex.clamp(0, headers.length - 1);
    final overlapping = mappingNotifier.findConflictingAssignment(selection);

    final localAnchor = _toStackLocal(anchor);
    final target =
        _toStackLocalRect(selectionState.bounds) ??
        Rect.fromPoints(localAnchor, localAnchor);

    // El cuadro se coloca midiendo su tamaño real: con una altura supuesta
    // quedaba más abajo de lo debido y tapaba el texto seleccionado.
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _TooltipLayoutDelegate(target: target),
        child: Material(
          elevation: 6,
          color: colors.surface,
          borderRadius: BorderRadius.circular(6),
          shadowColor: const Color(0x40000000),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 260,
              maxWidth: _maxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Asignar campo',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.foregroundPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (headers.isEmpty)
                    Text(
                      'Crea un campo nuevo con este texto o importa un Excel '
                      'para asignar campos.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: fieldIndex,
                          isExpanded: true,
                          isDense: true,
                          items: <DropdownMenuItem<int>>[
                            for (var index = 0; index < headers.length; index++)
                              DropdownMenuItem<int>(
                                value: index,
                                child: Text(
                                  headers[index],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            mappingNotifier.setCurrentFieldIndex(value);
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      FilledButton(
                        onPressed: headers.isEmpty
                            ? null
                            : () => assignWorkbenchSelection(context, ref),
                        child: const Text('Asignar'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            createFieldFromWorkbenchSelection(context, ref),
                        child: const Text('Crear campo nuevo'),
                      ),
                      OutlinedButton(
                        onPressed: headers.isEmpty || overlapping == null
                            ? null
                            : () => assignWorkbenchSelection(context, ref),
                        child: const Text('Cambiar mapeo'),
                      ),
                      OutlinedButton(
                        onPressed: overlapping == null
                            ? null
                            : () => _removeOverlapping(ref, overlapping),
                        child: const Text('Quitar mapeo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _toStackLocal(Offset globalAnchor) {
    final box = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return globalAnchor;
    }
    return box.globalToLocal(globalAnchor);
  }

  Rect? _toStackLocalRect(Rect? globalBounds) {
    if (globalBounds == null) {
      return null;
    }
    final box = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return globalBounds;
    }
    return Rect.fromPoints(
      box.globalToLocal(globalBounds.topLeft),
      box.globalToLocal(globalBounds.bottomRight),
    );
  }

  void _removeOverlapping(WidgetRef ref, FieldAssignment overlapping) {
    ref.read(activeMappingProvider.notifier).removeAssignment(overlapping.id);
    ref.read(workbenchSelectionProvider.notifier).clearSelection();
  }
}

/// Coloca el cuadro con su tamaño real junto al texto seleccionado sin
/// taparlo: primero arriba, luego abajo y, si no cabe, a un lado. Solo si en
/// ningún lado cabe entero se queda en el que más espacio tiene, pegado al
/// borde de la ventana.
final class _TooltipLayoutDelegate extends SingleChildLayoutDelegate {
  const _TooltipLayoutDelegate({required this.target});

  /// Texto seleccionado (o el punto de anclaje), en coordenadas del área.
  final Rect target;

  static const double _gap = 12;
  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = _clamp(target.left, size.width, childSize.width);
    final middle = _clamp(
      target.center.dy - childSize.height / 2,
      size.height,
      childSize.height,
    );

    final candidates = <Offset>[
      Offset(left, target.top - childSize.height - _gap),
      Offset(left, target.bottom + _gap),
      Offset(target.right + _gap, middle),
      Offset(target.left - childSize.width - _gap, middle),
    ];
    for (final candidate in candidates) {
      if (_fits(candidate, size, childSize)) {
        return candidate;
      }
    }

    final below = size.height - target.bottom >= target.top;
    final top = below
        ? target.bottom + _gap
        : target.top - childSize.height - _gap;
    return Offset(left, _clamp(top, size.height, childSize.height));
  }

  bool _fits(Offset topLeft, Size size, Size childSize) {
    return topLeft.dx >= _margin &&
        topLeft.dy >= _margin &&
        topLeft.dx + childSize.width <= size.width - _margin &&
        topLeft.dy + childSize.height <= size.height - _margin;
  }

  /// Deja el cuadro dentro de la ventana; si es más grande que ella, pegado
  /// al borde inicial.
  double _clamp(double preferred, double extent, double childExtent) {
    final max = extent - childExtent - _margin;
    return max < _margin
        ? _margin
        : math.min(math.max(preferred, _margin), max);
  }

  @override
  bool shouldRelayout(_TooltipLayoutDelegate oldDelegate) =>
      oldDelegate.target != target;
}
