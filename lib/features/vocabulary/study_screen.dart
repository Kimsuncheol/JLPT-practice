import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/data/models/review_progress.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({required this.day, super.key});

  final int day;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  int _index = 0;
  bool? _showFurigana;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final words = StudyBatches.wordsForDay(
      state.selectedVocabulary,
      day: widget.day,
      dailyGoal: state.dailyGoal,
    );
    _showFurigana ??= state.showFurigana;
    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.strings('noResults'))),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: words.length,
              onPageChanged: (index) {
                setState(() => _index = index);
                if (state.autoPlayAudio) {
                  ref.read(ttsServiceProvider).speak(words[index].word);
                }
              },
              itemBuilder: (context, index) {
                final word = words[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: _StudyCard(
                    vocabulary: word,
                    language: state.meaningLanguage,
                    showFurigana: _showFurigana!,
                    onToggleFurigana: () {
                      setState(() => _showFurigana = !_showFurigana!);
                    },
                    onSpeak: () =>
                        ref.read(ttsServiceProvider).speak(word.word),
                    onReview: () async {
                      await ref
                          .read(appControllerProvider.notifier)
                          .rateVocabulary(word.id, ReviewRating.again);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.strings('markReview')),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Text(
                '${_index + 1} / ${words.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({
    required this.vocabulary,
    required this.language,
    required this.showFurigana,
    required this.onToggleFurigana,
    required this.onSpeak,
    required this.onReview,
  });

  final Vocabulary vocabulary;
  final String language;
  final bool showFurigana;
  final VoidCallback onToggleFurigana;
  final VoidCallback onSpeak;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        child: Column(
          children: [
            Row(
              children: [
                Chip(
                  label: Text('${vocabulary.jlptLevel} · #${vocabulary.rank}'),
                ),
                if (vocabulary.partOfSpeech != 'word') ...[
                  const SizedBox(width: 6),
                  Chip(label: Text(vocabulary.partOfSpeech)),
                ],
              ],
            ),
            const SizedBox(height: 44),
            AnimatedOpacity(
              opacity: showFurigana ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Text(
                vocabulary.reading,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              vocabulary.word,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 56,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              vocabulary.romaji,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              vocabulary.meaning(language),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (vocabulary.hasExample) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Text(
                      vocabulary.example.sentence,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (showFurigana) ...[
                      const SizedBox(height: 6),
                      Text(
                        vocabulary.example.reading,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      vocabulary.example.translation(language),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CardAction(
                  icon: Icons.volume_up_rounded,
                  label: 'Audio',
                  onTap: onSpeak,
                ),
                _CardAction(
                  icon: showFurigana
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  label: showFurigana
                      ? context.strings('hideReading')
                      : context.strings('showReading'),
                  onTap: onToggleFurigana,
                ),
                _CardAction(
                  icon: Icons.bookmark_add_outlined,
                  label: context.strings('markReview'),
                  onTap: onReview,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );
}
