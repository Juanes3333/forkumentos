import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/export/domain/export_job.dart';
import 'package:forkumentos/features/export/domain/export_row_range.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';
import 'package:forkumentos/features/export/presentation/filename_pattern_editor.dart';
import 'package:forkumentos/shared/providers/settings_providers.dart';

/// Options collected before starting an export.
final class ExportDialogResult {
  const ExportDialogResult({required this.job});

  final ExportJob job;
}

/// Loads datasource values for the given row indexes (used to pre-fill the
/// manual filename fields with what the automatic pattern would produce).
typedef ExportRowValuesLoader =
    Future<Map<int, List<String?>>> Function(List<int> rowIndexes);

/// Export configuration dialog (destination, row range, filename, ZIP).
///
/// DOCX-only: the format picker, page-range section, and oversized-table
/// warning were removed (2026-08-03) with PDF export itself.
final class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({
    required this.destinationFolder,
    required this.headers,
    required this.sampleRow,
    required this.rowCount,
    required this.currentRowIndex,
    required this.missingFieldHeaders,
    required this.templateName,
    required this.loadRowValues,
    super.key,
  });

  final String destinationFolder;
  final List<String> headers;
  final List<String?> sampleRow;
  final int rowCount;
  final int currentRowIndex;
  final List<String> missingFieldHeaders;
  final String templateName;
  final ExportRowValuesLoader loadRowValues;

  static Future<ExportDialogResult?> show(
    BuildContext context, {
    required String destinationFolder,
    required List<String> headers,
    required List<String?> sampleRow,
    required int rowCount,
    required int currentRowIndex,
    required List<String> missingFieldHeaders,
    required String templateName,
    required ExportRowValuesLoader loadRowValues,
  }) {
    return showDialog<ExportDialogResult>(
      context: context,
      builder: (context) => ExportDialog(
        destinationFolder: destinationFolder,
        headers: headers,
        sampleRow: sampleRow,
        rowCount: rowCount,
        currentRowIndex: currentRowIndex,
        missingFieldHeaders: missingFieldHeaders,
        templateName: templateName,
        loadRowValues: loadRowValues,
      ),
    );
  }

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

final class _ExportDialogState extends ConsumerState<ExportDialog> {
  ExportRangeMode _rangeMode = ExportRangeMode.single;
  final _rangeController = TextEditingController();
  FilenamePattern _pattern = FilenamePattern.defaultPattern;
  FilenameMode _filenameMode = FilenameMode.automatic;

  /// Keyed by datasource row index so edits survive a range change.
  final _manualControllers = <int, TextEditingController>{};
  var _loadingManual = false;

  late bool _createZip;
  String? _rangeError;
  var _acknowledgedMissing = false;
  var _defaultsApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultsApplied) {
      return;
    }
    _createZip = ref.read(defaultCreateZipProvider);
    _defaultsApplied = true;
  }

  @override
  void dispose() {
    _rangeController.dispose();
    for (final controller in _manualControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasMissingWarning => widget.missingFieldHeaders.isNotEmpty;

  /// Row indexes for the current range selection, or `null` when the custom
  /// range is empty/invalid.
  List<int>? _resolveRowIndexes() {
    try {
      final indexes = switch (_rangeMode) {
        ExportRangeMode.single => <int>[widget.currentRowIndex],
        ExportRangeMode.batch => List<int>.generate(widget.rowCount, (i) => i),
        ExportRangeMode.custom => ExportRowRange.parse(
          _rangeController.text,
          rowCount: widget.rowCount,
        ),
      };
      return indexes.isEmpty ? null : indexes;
    } on FormatException {
      return null;
    }
  }

  void _onFilenameModeChanged(FilenameMode mode) {
    setState(() => _filenameMode = mode);
    if (mode == FilenameMode.manual) {
      _syncManualControllers();
    }
  }

  void _onRangeChanged() {
    if (_filenameMode == FilenameMode.manual) {
      _syncManualControllers();
    }
  }

  Future<void> _syncManualControllers() async {
    final rowIndexes = _resolveRowIndexes();
    if (rowIndexes == null) {
      return;
    }
    final missing = rowIndexes
        .where((index) => !_manualControllers.containsKey(index))
        .toList(growable: false);
    if (missing.isEmpty) {
      setState(() {});
      return;
    }

    setState(() => _loadingManual = true);
    final loaded = await widget.loadRowValues(missing);
    if (!mounted) {
      return;
    }
    for (final index in missing) {
      final values =
          loaded[index] ??
          List<String?>.filled(widget.headers.length, null);
      final autoName = _pattern.resolve(
        row: values,
        headers: widget.headers,
        templateName: widget.templateName,
      );
      _manualControllers[index] = TextEditingController(text: autoName);
    }
    setState(() => _loadingManual = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exportar'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_hasMissingWarning) ...<Widget>[
                Material(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Hay campos sin asignar: '
                          '${widget.missingFieldHeaders.join(', ')}. '
                          'Las regiones sin mapear conservan el texto '
                          'original de la plantilla.',
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Continuar de todos modos'),
                          value: _acknowledgedMissing,
                          onChanged: (value) {
                            setState(() {
                              _acknowledgedMissing = value ?? false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('Destino', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SelectableText(widget.destinationFolder),
              const SizedBox(height: 16),
              Text('Registros', style: Theme.of(context).textTheme.labelLarge),
              RadioGroup<ExportRangeMode>(
                groupValue: _rangeMode,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _rangeMode = value;
                    _rangeError = null;
                  });
                  _onRangeChanged();
                },
                child: Column(
                  children: <Widget>[
                    RadioListTile<ExportRangeMode>(
                      dense: true,
                      title: Text(
                        'Fila actual (fila ${widget.currentRowIndex + 1})',
                      ),
                      value: ExportRangeMode.single,
                    ),
                    RadioListTile<ExportRangeMode>(
                      dense: true,
                      title: Text('Todas las filas (${widget.rowCount})'),
                      value: ExportRangeMode.batch,
                    ),
                    const RadioListTile<ExportRangeMode>(
                      dense: true,
                      title: Text('Rango personalizado'),
                      value: ExportRangeMode.custom,
                    ),
                  ],
                ),
              ),
              if (_rangeMode == ExportRangeMode.custom) ...<Widget>[
                TextField(
                  controller: _rangeController,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Ej. 1-20,15,18-25',
                    errorText: _rangeError,
                  ),
                  onChanged: (_) {
                    if (_rangeError != null) {
                      setState(() => _rangeError = null);
                    }
                    _onRangeChanged();
                  },
                ),
              ],
              const SizedBox(height: 16),
              SegmentedButton<FilenameMode>(
                segments: const <ButtonSegment<FilenameMode>>[
                  ButtonSegment<FilenameMode>(
                    value: FilenameMode.automatic,
                    label: Text('Nombrado automático'),
                    icon: Icon(Icons.auto_awesome_outlined),
                  ),
                  ButtonSegment<FilenameMode>(
                    value: FilenameMode.manual,
                    label: Text('Nombrado manual'),
                    icon: Icon(Icons.edit_outlined),
                  ),
                ],
                selected: <FilenameMode>{_filenameMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  _onFilenameModeChanged(selection.first);
                },
              ),
              const SizedBox(height: 12),
              if (_filenameMode == FilenameMode.automatic)
                FilenamePatternEditor(
                  headers: widget.headers,
                  sampleRow: widget.sampleRow,
                  initialPattern: _pattern,
                  onChanged: (pattern) => _pattern = pattern,
                  templateName: widget.templateName,
                )
              else
                _ManualFilenameList(
                  rowIndexes: _resolveRowIndexes(),
                  controllers: _manualControllers,
                  isLoading: _loadingManual,
                ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Crear ZIP con los archivos generados'),
                value: _createZip,
                onChanged: (value) {
                  setState(() => _createZip = value ?? false);
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _canExport ? _submit : null,
          child: const Text('Exportar'),
        ),
      ],
    );
  }

  bool get _canExport {
    if (_hasMissingWarning && !_acknowledgedMissing) {
      return false;
    }
    return true;
  }

  void _submit() {
    List<int> rowIndexes;
    try {
      rowIndexes = switch (_rangeMode) {
        ExportRangeMode.single => <int>[widget.currentRowIndex],
        ExportRangeMode.batch => List<int>.generate(widget.rowCount, (i) => i),
        ExportRangeMode.custom => ExportRowRange.parse(
          _rangeController.text,
          rowCount: widget.rowCount,
        ),
      };
    } on FormatException catch (error) {
      setState(() => _rangeError = error.message);
      return;
    }

    if (rowIndexes.isEmpty) {
      setState(() => _rangeError = 'Selecciona al menos una fila.');
      return;
    }

    Map<int, String>? manualFilenames;
    if (_filenameMode == FilenameMode.manual) {
      manualFilenames = <int, String>{};
      for (var position = 0; position < rowIndexes.length; position++) {
        final text =
            _manualControllers[rowIndexes[position]]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          manualFilenames[position] = text;
        }
      }
    }

    Navigator.of(context).pop(
      ExportDialogResult(
        job: ExportJob(
          destinationFolder: widget.destinationFolder,
          filenamePattern: _pattern,
          rangeMode: _rangeMode,
          rowIndexes: rowIndexes,
          createZip: _createZip,
          templateBaseName: widget.templateName,
          filenameMode: _filenameMode,
          manualFilenames: manualFilenames,
          customRangeText: _rangeMode == ExportRangeMode.custom
              ? _rangeController.text
              : null,
        ),
      ),
    );
  }
}

final class _ManualFilenameList extends StatelessWidget {
  const _ManualFilenameList({
    required this.rowIndexes,
    required this.controllers,
    required this.isLoading,
  });

  final List<int>? rowIndexes;
  final Map<int, TextEditingController> controllers;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indexes = rowIndexes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Nombre de cada archivo',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Cada campo empieza con el nombre automático; edítalo a tu gusto. '
          '.docx se añade solo.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (indexes == null)
          Text(
            'Corrige el rango de filas para editar los nombres.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: indexes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, position) {
                final rowIndex = indexes[position];
                return TextField(
                  controller: controllers[rowIndex],
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Fila ${rowIndex + 1}',
                    suffixText: '.docx',
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
