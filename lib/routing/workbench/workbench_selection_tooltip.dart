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

  static const double _gap = 28;
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

    final localBounds = _toStackLocalRect(selectionState.bounds);
    final localAnchor = _toStackLocal(anchor);
    final stackSize = _stackSize();
    final position = _resolvePosition(
      anchor: localAnchor,
      bounds: localBounds,
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

  /// Prefer above, then below, then sides — always with [_gap] clearance from
  /// the selection bounds (or anchor). Left-align with the selection start.
  Offset _resolvePosition({
    required Offset anchor,
    required Rect? bounds,
    required Size stackSize,
  }) {
    final left = bounds?.left ?? anchor.dx;
    final top = bounds?.top ?? anchor.dy;
    final bottom = bounds?.bottom ?? anchor.dy;
    final midY = bounds == null
        ? anchor.dy - _approxHeight / 2
        : bounds.center.dy - _approxHeight / 2;

    final candidates = <Offset>[
      Offset(_clampLeft(left, stackSize.width), top - _approxHeight - _gap),
      Offset(_clampLeft(left, stackSize.width), bottom + _gap),
      Offset(
        (bounds?.right ?? anchor.dx) + _gap,
        _clampTop(midY, stackSize.height),
      ),
      Offset(left - _approxWidth - _gap, _clampTop(midY, stackSize.height)),
    ];

    for (final candidate in candidates) {
      if (_fits(candidate, stackSize)) {
        return candidate;
      }
    }

    return Offset(
      _clampLeft(left, stackSize.width),
      _clampTop(top - _approxHeight - _gap, stackSize.height),
    );
  }

  bool _fits(Offset topLeft, Size stackSize) {
    return topLeft.dx >= 0 &&
        topLeft.dy >= 0 &&
        topLeft.dx + _approxWidth <= stackSize.width &&
        topLeft.dy + _approxHeight <= stackSize.height;
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
