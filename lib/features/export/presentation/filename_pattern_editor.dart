import 'package:flutter/material.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';

/// Visual filename pattern editor (text + field chips, live preview).
final class FilenamePatternEditor extends StatefulWidget {
  const FilenamePatternEditor({
    required this.headers,
    required this.sampleRow,
    required this.initialPattern,
    required this.onChanged,
    super.key,
  });

  final List<String> headers;
  final List<String?> sampleRow;
  final FilenamePattern initialPattern;
  final ValueChanged<FilenamePattern> onChanged;

  @override
  State<FilenamePatternEditor> createState() => _FilenamePatternEditorState();
}

final class _FilenamePatternEditorState extends State<FilenamePatternEditor> {
  late List<FilenamePatternBlock> _blocks;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _blocks = List<FilenamePatternBlock>.of(widget.initialPattern.blocks);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  FilenamePattern get _pattern => FilenamePattern(blocks: _blocks);

  void _emit() {
    widget.onChanged(_pattern);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final preview = _pattern.resolve(
      row: widget.sampleRow,
      headers: widget.headers,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Nombre de archivo',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (var index = 0; index < _blocks.length; index++)
              _BlockChip(
                block: _blocks[index],
                onRemove: () {
                  setState(() {
                    _blocks = <FilenamePatternBlock>[
                      ..._blocks.take(index),
                      ..._blocks.skip(index + 1),
                    ];
                  });
                  _emit();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Texto literal',
                ),
                onSubmitted: (_) => _addText(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _addText,
              child: const Text('Añadir texto'),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<int>(
              tooltip: 'Añadir campo',
              onSelected: (fieldIndex) {
                setState(() {
                  _blocks = <FilenamePatternBlock>[
                    ..._blocks,
                    FilenameFieldBlock(
                      fieldIndex: fieldIndex,
                      fieldHeader: widget.headers[fieldIndex],
                    ),
                  ];
                });
                _emit();
              },
              itemBuilder: (context) => <PopupMenuEntry<int>>[
                for (var index = 0; index < widget.headers.length; index++)
                  PopupMenuItem<int>(
                    value: index,
                    child: Text(widget.headers[index]),
                  ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('Añadir campo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Vista previa: $preview',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _addText() {
    final text = _textController.text;
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _blocks = <FilenamePatternBlock>[..._blocks, FilenameTextBlock(text)];
      _textController.clear();
    });
    _emit();
  }
}

final class _BlockChip extends StatelessWidget {
  const _BlockChip({required this.block, required this.onRemove});

  final FilenamePatternBlock block;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = switch (block) {
      FilenameTextBlock(:final text) => '"$text"',
      FilenameFieldBlock(:final fieldHeader) => fieldHeader,
    };

    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      visualDensity: VisualDensity.compact,
    );
  }
}
