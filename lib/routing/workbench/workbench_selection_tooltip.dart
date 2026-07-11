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

  static const double _gap = 8;
  static const double _approxWidth = 280;
  static const double _approxHeight = 140;

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
    final stackSize = _stackSize();
    final position = _resolvePosition(
      anchor: localAnchor,
      stackSize: stackSize,
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        elevation: 6,
        color: colors.surface,
        borderRadius: BorderRadius.circular(6),
        shadowColor: const Color(0x40000000),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 260,
            maxWidth: _approxWidth,
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
                    'Importa una fuente de datos para asignar campos.',
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
    );
  }

  /// Anchor is treated as the bottom of the selection; prefer above first.
  Offset _resolvePosition({required Offset anchor, required Size stackSize}) {
    final aboveTop = anchor.dy - _approxHeight - _gap;
    if (aboveTop >= 0) {
      return Offset(_clampLeft(anchor.dx, stackSize.width), aboveTop);
    }

    final belowTop = anchor.dy + _gap;
    if (belowTop + _approxHeight <= stackSize.height) {
      return Offset(_clampLeft(anchor.dx, stackSize.width), belowTop);
    }

    final rightLeft = anchor.dx + _gap;
    if (rightLeft + _approxWidth <= stackSize.width) {
      return Offset(
        rightLeft,
        _clampTop(anchor.dy - _approxHeight / 2, stackSize.height),
      );
    }

    final leftLeft = anchor.dx - _approxWidth - _gap;
    return Offset(
      leftLeft.clamp(8.0, stackSize.width - _approxWidth - 8),
      _clampTop(anchor.dy - _approxHeight / 2, stackSize.height),
    );
  }

  double _clampLeft(double preferred, double stackWidth) {
    return preferred.clamp(8.0, stackWidth - _approxWidth - 8);
  }

  double _clampTop(double preferred, double stackHeight) {
    return preferred.clamp(8.0, stackHeight - _approxHeight - 8);
  }

  Size _stackSize() {
    final box = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return Size.infinite;
    }
    return box.size;
  }

  Offset _toStackLocal(Offset globalAnchor) {
    final box = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return globalAnchor;
    }
    return box.globalToLocal(globalAnchor);
  }

  void _removeOverlapping(WidgetRef ref, FieldAssignment overlapping) {
    ref.read(activeMappingProvider.notifier).removeAssignment(overlapping.id);
    ref.read(workbenchSelectionProvider.notifier).clearSelection();
  }
}
