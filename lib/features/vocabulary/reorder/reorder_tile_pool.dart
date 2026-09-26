import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/vocabulary/reorder/index_sticky_note.dart';
import 'package:jlpt_practice/features/vocabulary/sentence_reorder_quiz.dart';

class ReorderTilePool extends StatelessWidget {
  const ReorderTilePool({
    required this.tiles,
    required this.enabled,
    required this.onSelect,
    this.layoutTiles,
    super.key,
  });

  final List<SentenceToken> tiles;
  final List<SentenceToken>? layoutTiles;
  final bool enabled;
  final ValueChanged<SentenceToken> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark
        ? const Color(0xFF1D2C33)
        : const Color(0xFFEAF7FC);
    final borderColor = isDark
        ? const Color(0xFFA6D9EA)
        : const Color(0xFF6EA9BE);
    final lineColor = isDark
        ? const Color(0xFF31434A)
        : const Color(0xFFC8E0E8);
    final chipBorderColor = isDark
        ? const Color(0xFF5B565E)
        : const Color(0xFF6F6A70);
    final reservedTiles = layoutTiles ?? tiles;

    return SizedBox(
      width: double.infinity,
      child: IndexStickyNote(
        noteKey: const ValueKey('reorder-tile-pool-container'),
        label: context.strings('words'),
        labelColor: const Color(0xFF82D5EF),
        labelTextColor: const Color(0xFF18323D),
        surfaceColor: surfaceColor,
        borderColor: borderColor,
        child: CustomPaint(
          painter: IndexNoteLinesPainter(
            color: lineColor,
            firstLineY: 72,
            spacing: 52,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 90),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
              child: Stack(
                children: [
                  Visibility(
                    visible: false,
                    maintainAnimation: true,
                    maintainSize: true,
                    maintainState: true,
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      children: [
                        for (final tile in reservedTiles)
                          _WordTile(tile: tile, borderColor: chipBorderColor),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 12,
                        children: [
                          for (final tile in tiles)
                            _WordTile(
                              key: ValueKey('available-${tile.id}'),
                              tile: tile,
                              borderColor: chipBorderColor,
                              onPressed: enabled ? () => onSelect(tile) : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.tile,
    required this.borderColor,
    this.onPressed,
    super.key,
  });

  final SentenceToken tile;
  final Color borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(tile.text),
    labelStyle: const TextStyle(
      color: Color(0xFFF8F8F6),
      fontWeight: FontWeight.w700,
    ),
    backgroundColor: const Color(0xFF181818),
    disabledColor: const Color(0xFF242424),
    side: BorderSide(color: borderColor),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    onPressed: onPressed,
  );
}
