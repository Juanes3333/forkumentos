/// Mapping-agnostic placeholder for export replacements.
///
/// Routing maps feature mapping assignments into this type so
/// `features/export` never imports other features.
final class ExportPlaceholder {
  const ExportPlaceholder({
    required this.pageIndex,
    required this.steps,
    required this.startOffset,
    required this.endOffset,
    required this.fieldIndex,
  });

  final int pageIndex;
  final List<ExportPathStep> steps;
  final int startOffset;
  final int endOffset;
  final int fieldIndex;
}

/// Simple path step mirroring document body walk order.
sealed class ExportPathStep {
  const ExportPathStep();

  const factory ExportPathStep.rootBlock({required int blockIndex}) =
      ExportRootBlockStep;

  const factory ExportPathStep.cellBlock({
    required int rowIndex,
    required int cellIndex,
    required int blockIndex,
  }) = ExportCellBlockStep;
}

final class ExportRootBlockStep extends ExportPathStep {
  const ExportRootBlockStep({required this.blockIndex});

  final int blockIndex;
}

final class ExportCellBlockStep extends ExportPathStep {
  const ExportCellBlockStep({
    required this.rowIndex,
    required this.cellIndex,
    required this.blockIndex,
  });

  final int rowIndex;
  final int cellIndex;
  final int blockIndex;
}
