import 'package:flutter/material.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/mapping_color_palette.dart';
import 'package:forkumentos/features/mapping/domain/mapping_field_status.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path_resolver.dart';

final class MappingReviewSidebar extends StatefulWidget {
  const MappingReviewSidebar({
    required this.headers,
    required this.assignments,
    required this.onRemoveAssignment,
    required this.onNavigateToAssignment,
    required this.onNavigateToField,
    required this.onFieldHoverChanged,
    this.document,
    super.key,
  });

  final List<String> headers;
  final List<FieldAssignment> assignments;
  final ValueChanged<String> onRemoveAssignment;
  final ValueChanged<String> onNavigateToAssignment;
  final ValueChanged<int> onNavigateToField;
  final ValueChanged<int?> onFieldHoverChanged;

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

          return MouseRegion(
            onEnter: (_) => widget.onFieldHoverChanged(index),
            onExit: (_) => widget.onFieldHoverChanged(null),
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: Icon(Icons.circle, size: 12, color: color),
                    title: Text(widget.headers[index]),
                    subtitle: Text(
                      status == MappingFieldStatus.assigned
                          ? '$count asignación${count == 1 ? '' : 'es'}'
                          : 'Pendiente',
                    ),
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
                    for (final assignment in fieldAssignments)
                      ListTile(
                        dense: true,
                        title: Text(
                          '"${assignment.selectedText}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: _pageSubtitle(assignment),
                        trailing: IconButton(
                          tooltip: 'Quitar asignación',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () =>
                              widget.onRemoveAssignment(assignment.id),
                        ),
                        onTap: () =>
                            widget.onNavigateToAssignment(assignment.id),
                      ),
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
}
