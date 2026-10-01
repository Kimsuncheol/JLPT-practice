import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/vocabulary/reorder/index_sticky_note.dart';
import 'package:jlpt_practice/features/vocabulary/sentence_reorder_quiz.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_colors.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';
import 'package:jlpt_practice/core/constants/app_font_styles.dart';
import 'package:jlpt_practice/core/constants/app_spacing.dart';

class ReorderAnswerArea extends StatelessWidget {
  const ReorderAnswerArea({
    required this.selected,
    required this.translation,
    required this.attempt,
    required this.onRemove,
    super.key,
  });

  final List<SentenceToken> selected;
  final String translation;
  final QuizAttemptResult? attempt;
  final ValueChanged<SentenceToken> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppPalette.butterDark
        : AppPalette.butterLight;
    final borderColor = isDark
        ? AppPalette.butterBorderDark
        : AppPalette.butterAccentLight;
    final lineColor = isDark
        ? AppPalette.butterBorderDeep
        : AppPalette.butterBorderLight;
    final chipColor = isDark ? AppPalette.charcoal : AppPalette.charcoalWarm;
    final chipBorderColor = isDark
        ? AppPalette.taupeDark
        : AppPalette.taupeLight;
    final foregroundColor = isDark
        ? AppPalette.linenLight
        : AppPalette.linenDark;

    return IndexStickyNote(
      noteKey: const ValueKey('reorder-answer-container'),
      label: context.strings('answer'),
      labelColor: AppPalette.coralSoft,
      labelTextColor: AppPalette.coralInk,
      surfaceColor: surfaceColor,
      borderColor: borderColor,
      tabOnRight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomPaint(
            painter: IndexNoteLinesPainter(
              color: lineColor,
              firstLineY: 56,
              spacing: AppSpacing.item42,
              drawBottomRule: true,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.size88),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.size24,
                  AppSizes.size18,
                  AppSizes.size24,
                  AppSizes.size10,
                ),
                child: selected.isEmpty
                    ? Row(
                        children: [
                          Icon(
                            Icons.drag_indicator_rounded,
                            size: AppSizes.size22,
                            color: foregroundColor.withValues(alpha: 0.78),
                          ),
                          const SizedBox(width: AppSizes.space10),
                          Expanded(
                            child: Text(
                              context.strings('chooseWordToBegin'),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: foregroundColor.withValues(alpha: 0.82),
                                fontStyle: AppFontStyles.italic,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Wrap(
                        spacing: AppSpacing.item14,
                        runSpacing: AppSpacing.run8,
                        children: [
                          for (final (position, tile) in selected.indexed)
                            InputChip(
                              key: ValueKey('selected-${tile.id}'),
                              label: Text(tile.text),
                              labelStyle: TextStyle(
                                color:
                                    attempt?.wrongPositions.contains(
                                          position,
                                        ) ==
                                        true
                                    ? theme.colorScheme.onErrorContainer
                                    : AppPalette.paperWhite,
                                fontWeight: AppFontWeights.bold700,
                              ),
                              backgroundColor:
                                  attempt?.wrongPositions.contains(position) ==
                                      true
                                  ? theme.colorScheme.errorContainer
                                  : chipColor,
                              side: BorderSide(color: chipBorderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radius6,
                                ),
                              ),
                              elevation: 0,
                              onPressed: attempt == null
                                  ? () => onRemove(tile)
                                  : null,
                            ),
                        ],
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.size24,
              AppSizes.size14,
              AppSizes.size24,
              AppSizes.size18,
            ),
            child: Text(
              translation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
                fontWeight: AppFontWeights.semiBold,
                height: AppSizes.lineHeight1_4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
