import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/data/repositories/kanji_repository.dart';
import 'package:jlpt_practice/features/vocabulary/day_selection_screen.dart';
import 'package:jlpt_practice/features/vocabulary/study_finish/studied_words_section.dart';
import 'package:jlpt_practice/features/vocabulary/study_finish/study_finish_header.dart';
import 'package:jlpt_practice/features/vocabulary/start_over_button.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// Shown after the last kanji of a day: a summary of what was studied and the
/// button that completes the day.
class KanjiFinishScreen extends ConsumerWidget {
  const KanjiFinishScreen({required this.day, super.key});

  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    final catalog = ref.watch(kanjiCatalogProvider);
    if (asyncState.hasError || catalog.hasError) {
      return Scaffold(
        body: Center(child: Text('${asyncState.error ?? catalog.error}')),
      );
    }
    if (!asyncState.hasValue || !catalog.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final state = asyncState.requireValue;
    final todaysKanji = StudyBatches.wordsForDay(
      kanjiForLevel(catalog.requireValue, state.selectedLevel),
      day: day,
      dailyGoal: state.dailyGoal,
    );
    final strings = context.strings;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.size24,
            AppSizes.size24,
            AppSizes.size24,
            AppSizes.size20,
          ),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Center(
                  child: StudyFinishHeader(
                    title: strings('studyComplete'),
                    body: strings('kanjiStudyCompleteBody'),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: StudiedWordsSection(
                  words: [for (final item in todaysKanji) item.character],
                  onWordTap: (character) {
                    final item = todaysKanji.firstWhere(
                      (candidate) => candidate.character == character,
                    );
                    final reading =
                        item.frontKunYomi.firstOrNull ??
                        item.frontOnYomi.firstOrNull;
                    if (reading == null) return;
                    ref
                        .read(ttsServiceProvider)
                        .speak(kanjiReadingForSpeech(reading));
                  },
                ),
              ),
              const SizedBox(height: AppSizes.space16),
              StartOverButton(
                label: strings('startOver'),
                onPressed: () => _startOver(context, ref),
              ),
              const SizedBox(height: AppSizes.space10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  onPressed: () => _finish(context, ref, state.selectedLevel),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(strings('finish')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startOver(BuildContext context, WidgetRef ref) {
    ref.read(ttsServiceProvider).stop();
    context.pushReplacement('/kanji/day/$day?startOver=true');
  }

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    String level,
  ) async {
    ref.read(ttsServiceProvider).stop();
    await ref
        .read(appControllerProvider.notifier)
        .completeStudySession(StudyCourse.kanji.progressKey(level), day);
    if (!context.mounted) return;
    // go('/kanji') would leave the day list as the only route, so the system
    // back button would close the app. Rebuild home → day list instead.
    context.go('/home');
    context.push('/kanji');
  }
}
