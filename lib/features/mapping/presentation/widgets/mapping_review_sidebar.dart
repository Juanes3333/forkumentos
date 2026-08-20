import 'package:flutter/material.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_color_palette.dart';
import 'package:forkumentos/features/mapping/domain/mapping_field_status.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path_resolver.dart';

final class MappingReviewSidebar extends StatefulWidget {
  const MappingReviewSidebar({
    required this.headers,
    required this.previewRow,
    required this.assignments,
    required this.onRemoveAssignment,
    required this.onNavigateToAssignment,
    required this.onNavigateToField,
    required this.onFieldHoverChanged,
    required this.onSetAssignmentIsListField,
    required this.onAdjustParagraphSpan,
    this.document,
    super.key,
  });

  final List<String> headers;
  final List<String?> previewRow;
  final List<FieldAssignment> assignments;
  final ValueChanged<String> onRemoveAssignment;
  final ValueChanged<String> onNavigateToAssignment;
  final ValueChanged<int> onNavigateToField;
  final ValueChanged<int?> onFieldHoverChanged;

  /// Invocado cuando el usuario marca o desmarca "Campo de lista" para una
  /// asignación.
  final void Function({required String assignmentId, required bool isListField})
  onSetAssignmentIsListField;

  /// Invocado cuando el usuario usa los botones de expandir prosa multi-párrafo.
  final void Function({required String assignmentId, required int delta})
  onAdjustParagraphSpan;

  /// Documento activo, para resolver a qué página apunta cada asignación.
  /// `null` mientras el documento todavía carga: la página simplemente se
  /// omite del subtítulo hasta que haya uno disponible.
  final Document? document;

  @override
  State<MappingReviewSidebar> createState() => _MappingReviewSidebarState();
}

final class _MappingReviewSidebarState extends State<MappingReviewSidebar> {
  final Set<int> _expandedFieldIndexes = <int>{};

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: widget.headers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final fieldAssignments = widget.assignments
              .where((assignment) => assignment.fieldIndex == index)
              .toList();
          final count = fieldAssignments.length;
          final status = count > 0
              ? MappingFieldStatus.assigned
              : MappingFieldStatus.pending;
          final isExpanded = _expandedFieldIndexes.contains(index);
          final color = mappingColorForFieldIndex(index);
          final previewValue = index < widget.previewRow.length
              ? widget.previewRow[index]
              : null;

          return MouseRegion(
            onEnter: (_) => widget.onFieldHoverChanged(index),
            onExit: (_) => widget.onFieldHoverChanged(null),
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ListTile(
                    leading: Icon(Icons.circle, size: 12, color: color),
                    title: Text(widget.headers[index]),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          status == MappingFieldStatus.assigned
                              ? '$count asignación${count == 1 ? '' : 'es'}'
                              : 'Pendiente',
                        ),
                        const SizedBox(height: 2),
                        Tooltip(
                          message: previewValue ?? '(vacío)',
                          child: Text(
                            previewValue ?? '(vacío)',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).disabledColor,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedFieldIndexes.remove(index);
                        } else {
                          _expandedFieldIndexes.add(index);
                        }
                      });
                      widget.onNavigateToField(index);
                    },
                  ),
                  if (isExpanded)
                    for (final assignment in fieldAssignments) ...[
                      ListTile(
                        dense: true,
                        title: Row(
                          children: <Widget>[
                            if (assignment.isListField) ...<Widget>[
                              Tooltip(
                                message: 'Campo de lista',
                                child: Icon(
                                  Icons.format_list_numbered,
                                  size: 14,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                '"${assignment.selectedText}"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: _pageSubtitle(assignment),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (_paragraphHasNumbering(assignment))
                              Tooltip(
                                message: 'Campo de lista (numerada)',
                                child: Checkbox(
                                  value: assignment.isListField,
                                  onChanged: (value) =>
                                      widget.onSetAssignmentIsListField(
                                        assignmentId: assignment.id,
                                        isListField: value ?? false,
                                      ),
                                ),
                              ),
                            IconButton(
                              tooltip: 'Quitar asignación',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () =>
                                  widget.onRemoveAssignment(assignment.id),
                            ),
                          ],
                        ),
                        onTap: () =>
                            widget.onNavigateToAssignment(assignment.id),
                      ),
                      if (!_paragraphHasNumbering(assignment) && !assignment.isListField)
                        Padding(
                          padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              if ((assignment.paragraphSpan ?? 1) > 1)
                                Text(
                                  'Abarca ${assignment.paragraphSpan} párrafos',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).disabledColor,
                                  ),
                                ),
                              OutlinedButton.icon(
                                onPressed: () => widget.onAdjustParagraphSpan(
                                  assignmentId: assignment.id,
                                  delta: 1,
                                ),
                                icon: const Icon(Icons.arrow_downward, size: 14),
                                label: const Text('Incluir siguiente'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  textStyle: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                              if ((assignment.paragraphSpan ?? 1) > 1)
                                OutlinedButton.icon(
                                  onPressed: () => widget.onAdjustParagraphSpan(
                                    assignmentId: assignment.id,
                                    delta: -1,
                                  ),
                                  icon: const Icon(Icons.arrow_upward, size: 14),
                                  label: const Text('Excluir último'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    textStyle: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget? _pageSubtitle(FieldAssignment assignment) {
    final document = widget.document;
    final pageNumber = document == null
        ? null
        : resolvePageNumber(document, assignment.path);
    if (pageNumber == null) {
      return null;
    }
    return Text('Página ${pageNumber + 1}');
  }

  bool _paragraphHasNumbering(FieldAssignment assignment) {
    final document = widget.document;
    if (document == null) {
      return false;
    }
    try {
      return resolveParagraph(document, assignment.path).numberingId != null;
    } on DocumentTextPathResolutionException {
      return false;
    }
  }
}
