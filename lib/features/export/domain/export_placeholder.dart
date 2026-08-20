/// Mapping-agnostic placeholder for export replacements.
///
/// Routing maps feature mapping assignments into this type so
/// `features/export` never imports other features.
final class ExportPlaceholder {
  const ExportPlaceholder({
    required this.steps,
    required this.startOffset,
    required this.endOffset,
    required this.fieldIndex,
    this.isListField = false,
    this.paragraphSpan,
  });

  final List<ExportPathStep> steps;
  final int startOffset;
  final int endOffset;
  final int fieldIndex;

  /// When true, this is a "campo de lista": the exporter expands/contracts
  /// the numbered list starting at `steps`' root blockIndex to match the
  /// resolved value's line count, instead of substituting text in place.
  final bool isListField;

  /// When set and >1 (and [isListField] is false), this is a multi-paragraph
  /// prose field: the exporter replaces exactly this many consecutive
  /// paragraphs starting at `steps`' root blockIndex, instead of substituting
  /// text in place.
  final int? paragraphSpan;
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
