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

/// Export configuration dialog (format, destination, range, filename, ZIP).
final class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({
    required this.destinationFolder,
    required this.headers,
    required this.sampleRow,
    required this.rowCount,
    required this.currentRowIndex,
    required this.missingFieldHeaders,
    this.allowDocx = true,
    super.key,
  });

  final String destinationFolder;
  final List<String> headers;
  final List<String?> sampleRow;
  final int rowCount;
  final int currentRowIndex;
  final List<String> missingFieldHeaders;
  final bool allowDocx;

  static Future<ExportDialogResult?> show(
    BuildContext context, {
    required String destinationFolder,
    required List<String> headers,
    required List<String?> sampleRow,
    required int rowCount,
    required int currentRowIndex,
    required List<String> missingFieldHeaders,
    bool allowDocx = true,
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
        allowDocx: allowDocx,
      ),
    );
  }

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

final class _ExportDialogState extends ConsumerState<ExportDialog> {
  late ExportFormat _format;
  ExportRangeMode _rangeMode = ExportRangeMode.single;
  final _rangeController = TextEditingController();
  FilenamePattern _pattern = FilenamePattern.defaultPattern;
  late bool _createZip;
  String? _rangeError;
  var _acknowledgedMissing = false;
  var _defaultsApplied = false;

  @override
  void initState() {
    super.initState();
    if (widget.headers.isNotEmpty) {
      _pattern = FilenamePattern(
        blocks: <FilenamePatternBlock>[
          FilenameFieldBlock(fieldIndex: 0, fieldHeader: widget.headers.first),
        ],
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultsApplied) {
      return;
    }
    final preferred = _exportFormatFromSetting(
      ref.read(defaultExportFormatProvider),
    );
    _format = widget.allowDocx ? preferred : ExportFormat.pdf;
    if (!widget.allowDocx &&
        (_format == ExportFormat.docx || _format == ExportFormat.both)) {
      _format = ExportFormat.pdf;
    }
    _createZip = ref.read(defaultCreateZipProvider);
    _defaultsApplied = true;
  }

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  bool get _hasMissingWarning => widget.missingFieldHeaders.isNotEmpty;

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
              Text('Formato', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              if (widget.allowDocx)
                SegmentedButton<ExportFormat>(
                  segments: const <ButtonSegment<ExportFormat>>[
                    ButtonSegment(
                      value: ExportFormat.docx,
                      label: Text('DOCX'),
                    ),
                    ButtonSegment(value: ExportFormat.pdf, label: Text('PDF')),
                    ButtonSegment(
                      value: ExportFormat.both,
                      label: Text('Ambos'),
                    ),
                  ],
                  selected: <ExportFormat>{_format},
                  onSelectionChanged: (selected) {
                    setState(() => _format = selected.single);
                  },
                )
              else ...<Widget>[
                SegmentedButton<ExportFormat>(
                  segments: const <ButtonSegment<ExportFormat>>[
                    ButtonSegment(value: ExportFormat.pdf, label: Text('PDF')),
                  ],
                  selected: const <ExportFormat>{ExportFormat.pdf},
                  onSelectionChanged: (_) {},
                ),
                const SizedBox(height: 8),
                Text(
                  'La plantilla PDF solo permite exportar a PDF '
                  '(DOCX no está disponible).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
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
                  },
                ),
              ],
              const SizedBox(height: 16),
              FilenamePatternEditor(
                headers: widget.headers,
                sampleRow: widget.sampleRow,
                initialPattern: _pattern,
                onChanged: (pattern) => _pattern = pattern,
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

    final format = widget.allowDocx ? _format : ExportFormat.pdf;

    Navigator.of(context).pop(
      ExportDialogResult(
        job: ExportJob(
          format: format,
          destinationFolder: widget.destinationFolder,
          filenamePattern: _pattern,
          rangeMode: _rangeMode,
          rowIndexes: rowIndexes,
          createZip: _createZip,
          customRangeText: _rangeMode == ExportRangeMode.custom
              ? _rangeController.text
              : null,
        ),
      ),
    );
  }
}

ExportFormat _exportFormatFromSetting(String value) {
  return switch (value) {
    'pdf' => ExportFormat.pdf,
    'both' => ExportFormat.both,
    _ => ExportFormat.docx,
  };
}
