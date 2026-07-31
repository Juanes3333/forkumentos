import 'package:flutter/material.dart';
import 'package:forkumentos/features/mapping/domain/text_occurrence.dart';

final class MultipleOccurrencesDialog extends StatefulWidget {
  const MultipleOccurrencesDialog({required this.occurrences, super.key});

  final List<TextOccurrence> occurrences;

  static Future<List<TextOccurrence>?> show(
    BuildContext context, {
    required List<TextOccurrence> occurrences,
  }) {
    return showDialog<List<TextOccurrence>>(
      context: context,
      builder: (context) => MultipleOccurrencesDialog(occurrences: occurrences),
    );
  }

  @override
  State<MultipleOccurrencesDialog> createState() =>
      _MultipleOccurrencesDialogState();
}

final class _MultipleOccurrencesDialogState
    extends State<MultipleOccurrencesDialog> {
  late final List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<bool>.filled(widget.occurrences.length, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Expanded(child: Text('Coincidencias adicionales')),
          IconButton(
            tooltip: 'Cancelar',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Se encontró texto idéntico adicional. '
              '¿Deseas asignar más ocurrencias?',
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.occurrences.length,
                itemBuilder: (context, index) {
                  final occurrence = widget.occurrences[index];
                  return CheckboxListTile(
                    value: _selected[index],
                    onChanged: (value) {
                      setState(() {
                        _selected[index] = value ?? false;
                      });
                    },
                    title: Text('Página ${occurrence.path.pageIndex + 1}'),
                    subtitle: Text('"...${occurrence.matchedText}..."'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(const <TextOccurrence>[]),
          child: const Text('Solo la actual'),
        ),
        OutlinedButton(
          onPressed: () {
            final selected = <TextOccurrence>[];
            for (var index = 0; index < widget.occurrences.length; index++) {
              if (_selected[index]) {
                selected.add(widget.occurrences[index]);
              }
            }
            Navigator.of(context).pop(selected);
          },
          child: const Text('Asignar seleccionadas'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(widget.occurrences),
          child: const Text('Asignar todas'),
        ),
      ],
    );
  }
}
