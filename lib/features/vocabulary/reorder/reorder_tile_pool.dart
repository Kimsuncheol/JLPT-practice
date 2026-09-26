import 'package:flutter/material.dart';
import 'package:jlpt_practice/features/vocabulary/sentence_reorder_quiz.dart';

class ReorderTilePool extends StatelessWidget {
  const ReorderTilePool({
    required this.tiles,
    required this.enabled,
    required this.onSelect,
    super.key,
  });
  final List<SentenceToken> tiles;
  final bool enabled;
  final ValueChanged<SentenceToken> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final tile in tiles)
        ActionChip(
          key: ValueKey('available-${tile.id}'),
          label: Text(tile.text),
          onPressed: enabled ? () => onSelect(tile) : null,
        ),
    ],
  );
}
