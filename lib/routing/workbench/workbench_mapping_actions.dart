import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/domain/draft_datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/datasource/presentation/datasource_sync_controller.dart';
import 'package:forkumentos/features/mapping/domain/auto_mapping.dart';
import 'package:forkumentos/features/mapping/domain/field_assignment.dart';
import 'package:forkumentos/features/mapping/domain/field_insertion.dart';
import 'package:forkumentos/features/mapping/domain/text_occurrence.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/multiple_occurrences_dialog.dart';
import 'package:forkumentos/features/mapping/presentation/widgets/new_field_dialog.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/routing/workbench/workbench_selection_provider.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/document_content_provider.dart';
import 'package:uuid/uuid.dart';

/// Coincidencias en una misma columna a partir de las cuales el auto-mapeo
/// pide confirmación antes de tocar el estado.
///
/// Un valor corto de la primera fila —`"1"`, `"A"`, `"2026"`— coincide dentro
/// de "Artículo 1", "$1.500", números de página y años. Cada coincidencia
/// queda como destino real de sustitución al exportar, así que esa columna
/// reescribiría texto que debía quedarse igual. El umbral solo decide cuándo
/// interrumpir; lo que permite juzgar es la cuenta exacta de cada columna,
/// que es lo que se muestra en el diálogo.
const int autoMappingOccurrenceWarningThreshold = 10;

/// Columna cuyo valor de primera fila se repite por encima del umbral.
typedef _CrowdedColumn = ({String header, int count});

/// Mapea de una pasada cada columna de la fuente buscando en el documento los
/// valores de su primera fila.
Future<void> autoMapWorkbench(BuildContext context, WidgetRef ref) async {
  final datasource = ref.read(activeDatasourceProvider).valueOrNull;
  final templatePath = ref.read(activeTemplateProvider).valueOrNull?.sourcePath;
  final document = templatePath == null
      ? null
      : ref.read(documentContentProvider(templatePath)).valueOrNull;
  if (datasource == null || document == null) {
    return;
  }

  final result = buildAutoMapping(
    document: document,
    headers: datasource.headers,
    firstRow: datasource.previewRow,
    existingAssignments: ref.read(activeMappingProvider).state.assignments,
    generateId: const Uuid().v4,
  );

  if (result.assignments.isEmpty) {
    _showMappingSnackBar(
      context,
      'Ningún valor de la primera fila aparece en el documento. '
      'Selecciona el texto y asigna los campos a mano.',
    );
    return;
  }

  final crowded = _crowdedColumns(datasource.headers, result);
  if (crowded.isNotEmpty) {
    final shouldContinue = await _askContinueCrowdedAutoMapping(
      context,
      crowded,
    );
    if (!shouldContinue) {
      return;
    }
  }
  if (!context.mounted) {
    return;
  }

  final addedCount = ref
      .read(activeMappingProvider.notifier)
      .applyAutoMapping(result);
  _showMappingSnackBar(
    context,
    '$addedCount campos auto-mapeados. Revisa y ajusta si es necesario.',
  );
}

List<_CrowdedColumn> _crowdedColumns(
  List<String> headers,
  AutoMappingResult result,
) {
  final crowded = <_CrowdedColumn>[
    for (final entry in result.occurrenceCountsByField.entries)
      if (entry.value > autoMappingOccurrenceWarningThreshold)
        (header: headers[entry.key], count: entry.value),
  ]..sort((a, b) => b.count.compareTo(a.count));

  return crowded;
}

Future<bool> _askContinueCrowdedAutoMapping(
  BuildContext context,
  List<_CrowdedColumn> columns,
) async {
  final theme = Theme.of(context);
  final textTheme = theme.textTheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Coincidencias repetidas'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Estos valores de la primera fila aparecen muchas veces en el '
                'documento. Al exportar, cada coincidencia se sustituye por el '
                'dato de la fila, así que las que no correspondan reescribirán '
                'texto que debía quedarse igual.',
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final column in columns)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '"${column.header}"',
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${column.count} coincidencias',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

void _showMappingSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

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
    if (extras == null) {
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
  if (extras == null) {
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

/// Crea un campo nuevo a partir del texto seleccionado: pide el nombre,
/// agrega la columna al Excel del proyecto (en el orden del documento) y asigna
/// la selección a ese campo. Si el Excel está abierto en Excel, ofrece
/// reintentar tras cerrarlo; nada se crea hasta que se pueda escribir.
Future<void> createFieldFromWorkbenchSelection(
  BuildContext context,
  WidgetRef ref,
) async {
  final selection = ref.read(workbenchSelectionProvider).selection;
  final datasource = ref.read(activeDatasourceProvider).valueOrNull;
  if (selection == null) {
    return;
  }
  // Sin Excel todavía (proyecto solo con Word) los campos se van guardando
  // en el proyecto hasta generar el Excel.
  final isDraft = datasource == null || datasource.isDraft;
  final headers = datasource?.headers ?? const <String>[];

  final name = await showNewFieldDialog(
    context,
    existingHeaders: headers,
    selectedText: selection.selectedText,
  );
  if (name == null || !context.mounted) {
    return;
  }

  final controller = ref.read(datasourceSyncControllerProvider);
  final insertAt = insertionIndexForNewField(
    assignments: ref.read(activeMappingProvider).state.assignments,
    path: selection.path,
    offset: selection.startOffset,
    headerCount: headers.length,
  );

  var appendedAtEnd = false;
  if (isDraft) {
    // Proyecto solo con Word: el campo queda en la lista del proyecto y el
    // Excel se genera después a partir de ella.
    ref.read(activeProjectProvider.notifier).insertDraftField(name, insertAt);
  } else {
    AddColumnOutcome outcome;
    do {
      outcome = await controller.addColumn(header: name, insertAt: insertAt);
      if (!context.mounted) {
        return;
      }
    } while (outcome.status == AddColumnStatus.locked &&
        await _askRetryExcelLocked(context) &&
        context.mounted);

    if (outcome.status != AddColumnStatus.success) {
      if (outcome.status != AddColumnStatus.locked) {
        _showMappingSnackBar(
          context,
          outcome.message ?? 'No se pudo crear el campo.',
        );
      }
      return;
    }
    appendedAtEnd = outcome.appendedAtEnd ?? false;
  }

  // Al refrescar, el Excel activo se vuelve a leer de forma asíncrona: se
  // espera a que ya traiga la columna nueva.
  final index = await _waitForHeader(ref, name);
  if (!context.mounted) {
    return;
  }
  if (index == null) {
    _showMappingSnackBar(
      context,
      'El campo se agregó, pero no se pudo leer todavía. Refresca los datos '
      'y asígnalo.',
    );
    return;
  }
  if (appendedAtEnd) {
    _showMappingSnackBar(
      context,
      'El Excel tiene fórmulas o tablas: el campo «$name» se agregó al final '
      'para no romperlas.',
    );
  }
  ref.read(activeMappingProvider.notifier).setCurrentFieldIndex(index);
  await assignWorkbenchSelection(context, ref);
}

Future<int?> _waitForHeader(WidgetRef ref, String header) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final headers =
        ref.read(activeDatasourceProvider).valueOrNull?.headers ??
        const <String>[];
    final index = headers.indexOf(header);
    if (index != -1) {
      return index;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return null;
}

Future<bool> _askRetryExcelLocked(BuildContext context) async {
  final retry = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('El Excel está abierto'),
      content: const Text(
        'Para agregar el campo hay que escribir en el Excel del proyecto. '
        'Guarda y cierra el archivo en Excel y pulsa Reintentar.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Reintentar'),
        ),
      ],
    ),
  );
  return retry ?? false;
}

Future<List<TextOccurrence>?> _resolveExtraOccurrences(
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

  return MultipleOccurrencesDialog.show(
    context,
    occurrences: additional,
    document: document,
  );
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
