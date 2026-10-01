import 'package:flutter/material.dart';
import 'package:jlpt_practice/features/vocabulary/study_finish/word_chip.dart';
import 'package:jlpt_practice/core/constants/app_spacing.dart';

class StudiedWordsSection extends StatelessWidget {
  const StudiedWordsSection({
    required this.words,
    required this.onWordTap,
    super.key,
  });

  final List<String> words;
  final ValueChanged<String> onWordTap;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      child: Wrap(
        spacing: AppSpacing.item8,
        runSpacing: AppSpacing.run8,
        alignment: WrapAlignment.center,
        children: [
          for (final word in words)
            WordChip(word: word, onTap: () => onWordTap(word)),
        ],
      ),
    );
  }
}
