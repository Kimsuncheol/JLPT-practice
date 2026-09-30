import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/vocabulary/reorder/index_sticky_note.dart';
import 'package:jlpt_practice/features/vocabulary/sentence_reorder_quiz.dart';

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
        ? const Color(0xFF35321D)
        : const Color(0xFFFFF9DC);
    final borderColor = isDark
        ? const Color(0xFFD4C45D)
        : const Color(0xFFB19B32);
    final lineColor = isDark
        ? const Color(0xFF514D32)
        : const Color(0xFFDED5A5);
    final chipColor = isDark
        ? const Color(0xFF181818)
        : const Color(0xFF262522);
    final chipBorderColor = isDark
        ? const Color(0xFF5C565C)
        : const Color(0xFF706B65);
    final foregroundColor = isDark
        ? const Color(0xFFF3F1EC)
        : const Color(0xFF292720);

    return IndexStickyNote(
      noteKey: const ValueKey('reorder-answer-container'),
      label: context.strings('answer'),
      labelColor: const Color(0xFFFF8E78),
      labelTextColor: const Color(0xFF402820),
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
              spacing: 42,
              drawBottomRule: true,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
                child: selected.isEmpty
                    ? Row(
                        children: [
                          Icon(
                            Icons.drag_indicator_rounded,
                            size: 22,
                            color: foregroundColor.withValues(alpha: 0.78),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.strings('chooseWordToBegin'),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: foregroundColor.withValues(alpha: 0.82),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Wrap(
                        spacing: 14,
                        runSpacing: 8,
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
                                    : const Color(0xFFF8F8F6),
                                fontWeight: FontWeight.w700,
                              ),
                              backgroundColor:
                                  attempt?.wrongPositions.contains(position) ==
                                      true
                                  ? theme.colorScheme.errorContainer
                                  : chipColor,
                              side: BorderSide(color: chipBorderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
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
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
            child: Text(
              translation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
