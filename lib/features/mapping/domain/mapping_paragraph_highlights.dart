import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_color_palette.dart';
import 'package:forkumentos/features/mapping/domain/text_occurrence.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/widgets/mapping_aware_paragraph.dart';

List<ParagraphHighlightSegment> buildParagraphHighlights({
  required DocumentTextPath path,
  required List<FieldAssignment> assignments,
  required List<TextOccurrence> suggestions,
  required int? hoveredFieldIndex,
  required int activeFieldIndex,
  String? emphasizedAssignmentId,
}) {
  final highlights = <ParagraphHighlightSegment>[];

  for (final assignment in assignments) {
    if (assignment.path != path) {
      continue;
    }

    final color = mappingColorForFieldIndex(assignment.fieldIndex);
    final emphasize =
        emphasizedAssignmentId == assignment.id ||
        hoveredFieldIndex == assignment.fieldIndex;
    highlights.add(
      ParagraphHighlightSegment(
        startOffset: assignment.startOffset,
        endOffset: assignment.endOffset,
        color: color,
        emphasize: emphasize,
      ),
    );
  }

  for (final suggestion in suggestions) {
    if (suggestion.path != path) {
      continue;
    }

    highlights.add(
      ParagraphHighlightSegment(
        startOffset: suggestion.startOffset,
        endOffset: suggestion.endOffset,
        color: mappingColorForFieldIndex(activeFieldIndex),
        isSuggestion: true,
      ),
    );
  }

  return highlights;
}
