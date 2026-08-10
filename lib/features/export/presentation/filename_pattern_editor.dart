import 'package:flutter/material.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/features/export/domain/filename_pattern.dart';

/// Visual filename pattern editor (text + field chips, live preview).
final class FilenamePatternEditor extends StatefulWidget {
  const FilenamePatternEditor({
    required this.headers,
    required this.sampleRow,
    required this.initialPattern,
    required this.onChanged,
    required this.templateName,
    super.key,
  });

  final List<String> headers;
  final List<String?> sampleRow;
  final FilenamePattern initialPattern;
  final ValueChanged<FilenamePattern> onChanged;
  final String templateName;

  @override
  State<FilenamePatternEditor> createState() => _FilenamePatternEditorState();
}

final class _FilenamePatternEditorState extends State<FilenamePatternEditor> {
  late List<_EditableBlock> _blocks;
  final _textController = TextEditingController();
  var _idSeed = 0;

  @override
  void initState() {
    super.initState();
    _blocks = <_EditableBlock>[
      for (final block in widget.initialPattern.blocks)
        _EditableBlock(id: _idSeed++, block: block),
    ];
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  FilenamePattern get _pattern => FilenamePattern(
    blocks: _blocks.map((entry) => entry.block).toList(growable: false),
  );

  void _emit() {
    widget.onChanged(_pattern);
    setState(() {});
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, item);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final preview = _pattern.resolve(
      row: widget.sampleRow,
      headers: widget.headers,
      templateName: widget.templateName,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Nombre de archivo', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            onReorderItem: _reorder,
            itemCount: _blocks.length,
            itemBuilder: (context, index) {
              final entry = _blocks[index];
              return ReorderableDragStartListener(
                key: ValueKey<int>(entry.id),
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _BlockChip(
                    block: entry.block,
                    onRemove: () {
                      setState(() {
                        _blocks = <_EditableBlock>[
                          ..._blocks.take(index),
                          ..._blocks.skip(index + 1),
                        ];
                      });
                      _emit();
                    },
                  ),
                ),
              );
            },
          ),
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
            FilledButton(
              onPressed: _addText,
              child: const Text('Añadir texto'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: _addTemplateName,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Añadir nombre de plantilla'),
              style: FilledButton.styleFrom(
                foregroundColor: colors.success,
                backgroundColor: Color.alphaBlend(
                  colors.success.withValues(alpha: 0.16),
                  colors.surface,
                ),
              ),
            ),
            PopupMenuButton<int>(
              tooltip: 'Añadir campo',
              onSelected: (fieldIndex) {
                setState(() {
                  _blocks = <_EditableBlock>[
                    ..._blocks,
                    _EditableBlock(
                      id: _idSeed++,
                      block: FilenameFieldBlock(
                        fieldIndex: fieldIndex,
                        fieldHeader: widget.headers[fieldIndex],
                      ),
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
              child: IgnorePointer(
                child: FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('Añadir campo'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Vista previa: $preview',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colors.foregroundPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _addTemplateName() {
    setState(() {
      _blocks = <_EditableBlock>[
        ..._blocks,
        _EditableBlock(id: _idSeed++, block: const FilenameTemplateBlock()),
      ];
    });
    _emit();
  }

  void _addText() {
    final text = _textController.text;
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _blocks = <_EditableBlock>[
        ..._blocks,
        _EditableBlock(id: _idSeed++, block: FilenameTextBlock(text)),
      ];
      _textController.clear();
    });
    _emit();
  }
}

final class _EditableBlock {
  const _EditableBlock({required this.id, required this.block});

  final int id;
  final FilenamePatternBlock block;
}

final class _BlockChip extends StatelessWidget {
  const _BlockChip({required this.block, required this.onRemove});

  final FilenamePatternBlock block;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isField = block is FilenameFieldBlock;
    final isTemplate = block is FilenameTemplateBlock;
    final accent = isTemplate ? colors.success : colors.accent;
    final label = switch (block) {
      FilenameTextBlock(:final text) => '"$text"',
      FilenameFieldBlock(:final fieldHeader) => fieldHeader,
      FilenameTemplateBlock() => 'Nombre de plantilla',
    };

    return InputChip(
      avatar: isTemplate
          ? Icon(Icons.description_outlined, size: 16, color: accent)
          : null,
      label: Text(
        label,
        style: TextStyle(
          color: isField || isTemplate ? accent : colors.foregroundPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      onDeleted: onRemove,
      deleteIconColor: isField || isTemplate ? accent : colors.foregroundMuted,
      visualDensity: VisualDensity.compact,
      backgroundColor: isField || isTemplate
          ? Color.alphaBlend(accent.withValues(alpha: 0.18), colors.surface)
          : colors.backgroundSecondary,
      side: BorderSide(
        color: isField || isTemplate ? accent : colors.border,
        width: isField || isTemplate ? 1.5 : 1.25,
      ),
    );
  }
}
