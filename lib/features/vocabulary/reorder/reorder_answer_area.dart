import 'package:flutter/material.dart';
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
    return Container(
      key: const ValueKey('reorder-answer-container'),
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF292C2E)
            : const Color(0xFFE8EAEB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (position, tile) in selected.indexed)
                InputChip(
                  key: ValueKey('selected-${tile.id}'),
                  label: Text(tile.text),
                  backgroundColor:
                      attempt?.wrongPositions.contains(position) == true
                      ? theme.colorScheme.errorContainer
                      : null,
                  onPressed: attempt == null ? () => onRemove(tile) : null,
                ),
            ],
          ),
          if (selected.isNotEmpty) const SizedBox(height: 14),
          Text(
            translation,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
