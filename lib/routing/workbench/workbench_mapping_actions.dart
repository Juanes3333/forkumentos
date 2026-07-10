import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/text_occurrence.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/multiple_occurrences_dialog.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_selection_provider.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/providers/document_content_provider.dart';

Future<void> assignWorkbenchSelection(
  BuildContext context,
  WidgetRef ref,
) async {
  final selectionState = ref.read(workbenchSelectionProvider);
  final selection = selectionState.selection;
  final datasource = ref.read(activeDatasourceProvider).valueOrNull;
  final templatePath = ref.read(activeTemplateProvider).valueOrNull?.sourcePath;
  final document = templatePath == null
      ? null
      : ref.read(documentContentProvider(templatePath)).valueOrNull;
  if (selection == null || datasource == null || document == null) {
    return;
  }

  final headers = datasource.headers;
  final mappingNotifier = ref.read(activeMappingProvider.notifier);
  final mappingState = ref.read(activeMappingProvider).state;
  final fieldIndex = mappingState.currentFieldIndex;
  final fieldHeader = headers[fieldIndex];

  final conflict = mappingNotifier.findConflictingAssignment(selection);
  if (conflict != null) {
    final shouldReplace = await _askReplaceAssignment(context, conflict);
    if (!context.mounted) {
      return;
    }
    if (!shouldReplace) {
      return;
    }

    final primary = FieldAssignment(
      id: conflict.id,
      fieldIndex: fieldIndex,
      fieldHeader: fieldHeader,
      selectedText: selection.selectedText.trim(),
      path: selection.path,
      startOffset: selection.startOffset,
      endOffset: selection.endOffset,
    );
    final extras = await _resolveExtraOccurrences(
      context,
      ref,
      document,
      primary,
    );
    if (!context.mounted) {
      return;
    }

    mappingNotifier.replaceAssignment(
      existingAssignment: conflict,
      selection: selection,
      fieldHeader: fieldHeader,
      fieldIndex: fieldIndex,
      extraOccurrences: extras,
    );
    ref.read(workbenchSelectionProvider.notifier).clearSelection();
    return;
  }

  final primary = FieldAssignment(
    id: 'pending',
    fieldIndex: fieldIndex,
    fieldHeader: fieldHeader,
    selectedText: selection.selectedText.trim(),
    path: selection.path,
    startOffset: selection.startOffset,
    endOffset: selection.endOffset,
  );
  final extras = await _resolveExtraOccurrences(
    context,
    ref,
    document,
    primary,
  );
  if (!context.mounted) {
    return;
  }

  mappingNotifier.confirmAssignment(
    selection: selection,
    fieldHeader: fieldHeader,
    fieldIndex: fieldIndex,
    headerCount: headers.length,
    extraOccurrences: extras,
  );
  ref.read(workbenchSelectionProvider.notifier).clearSelection();
}

Future<List<TextOccurrence>> _resolveExtraOccurrences(
  BuildContext context,
  WidgetRef ref,
  Document document,
  FieldAssignment primary,
) async {
  final additional = ref
      .read(activeMappingProvider.notifier)
      .findAdditionalOccurrences(
        document: document,
        primaryAssignment: primary,
      );
  if (additional.isEmpty) {
    return const <TextOccurrence>[];
  }

  final selected = await MultipleOccurrencesDialog.show(
    context,
    occurrences: additional,
  );
  return selected ?? const <TextOccurrence>[];
}

Future<bool> _askReplaceAssignment(
  BuildContext context,
  FieldAssignment existing,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Texto ya asignado'),
        content: Text(
          'Este texto ya pertenece al campo "${existing.fieldHeader}". '
          '¿Deseas reemplazar la asignación?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reemplazar'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
