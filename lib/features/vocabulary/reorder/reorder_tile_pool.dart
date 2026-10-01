import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/vocabulary/reorder/index_sticky_note.dart';
import 'package:jlpt_practice/features/vocabulary/sentence_reorder_quiz.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_colors.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';
import 'package:jlpt_practice/core/constants/app_spacing.dart';

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
        ? AppPalette.skyTintDark
        : AppPalette.skyTintLight;
    final borderColor = isDark
        ? AppPalette.skyAccentDark
        : AppPalette.skyAccentLight;
    final lineColor = isDark
        ? AppPalette.skyBorderDark
        : AppPalette.skyBorderLight;
    final chipBorderColor = isDark
        ? AppPalette.mauveDark
        : AppPalette.mauveLight;
    final reservedTiles = layoutTiles ?? tiles;

    return SizedBox(
      width: double.infinity,
      child: IndexStickyNote(
        noteKey: const ValueKey('reorder-tile-pool-container'),
        label: context.strings('words'),
        labelColor: AppPalette.skyLabel,
        labelTextColor: AppPalette.skyInk,
        surfaceColor: surfaceColor,
        borderColor: borderColor,
        child: CustomPaint(
          painter: IndexNoteLinesPainter(
            color: lineColor,
            firstLineY: 72 + AppSpacing.item8,
            spacing: AppSizes.size48 + AppSpacing.run20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.size90),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.size24,
                AppSizes.size28,
                AppSizes.size24,
                AppSizes.size14 + AppSpacing.item8,
              ),
              child: Stack(
                children: [
                  Visibility(
                    visible: false,
                    maintainAnimation: true,
                    maintainSize: true,
                    maintainState: true,
                    child: Wrap(
                      spacing: AppSpacing.item14,
                      runSpacing: AppSpacing.run20,
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
                        spacing: AppSpacing.item14,
                        runSpacing: AppSpacing.run20,
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
      color: AppPalette.paperWhite,
      fontWeight: AppFontWeights.bold700,
    ),
    backgroundColor: AppPalette.charcoal,
    disabledColor: AppPalette.charcoalLight,
    side: BorderSide(color: borderColor),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radius6),
    ),
    elevation: 0,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSizes.size10,
      vertical: AppSizes.size9,
    ),
    onPressed: onPressed,
  );
}
