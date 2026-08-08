import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/services/local_store.dart';
import 'package:jlpt_practice/data/models/grammar_progress.dart';

final grammarProgressProvider =
    AsyncNotifierProvider<
      GrammarProgressController,
      Map<String, GrammarProgress>
    >(GrammarProgressController.new);

class GrammarProgressController
    extends AsyncNotifier<Map<String, GrammarProgress>> {
  late LocalStore _store;

  @override
  Future<Map<String, GrammarProgress>> build() async {
    _store = await LocalStore.create();
    return _store.loadGrammarProgress();
  }

  Future<void> record({
    required String grammarId,
    required int correct,
    required int attempts,
    int? productionScore,
    String? mistake,
  }) async {
    final current = state.value?[grammarId];
    final now = DateTime.now();
    final totalAttempts = (current?.attempts ?? 0) + attempts;
    final totalCorrect = (current?.correctAnswers ?? 0) + correct;
    final nextProductionScore =
        productionScore ?? current?.productionScore ?? 0;
    final accuracy = totalAttempts == 0 ? 0.0 : totalCorrect / totalAttempts;
    final reviewDelay = nextProductionScore >= 2 && accuracy >= .8
        ? const Duration(days: 7)
        : accuracy >= .6
        ? const Duration(days: 3)
        : const Duration(days: 1);
    final updated = GrammarProgress(
      grammarId: grammarId,
      attempts: totalAttempts,
      correctAnswers: totalCorrect,
      productionScore: nextProductionScore,
      lastMistake: mistake,
      lastPractisedAt: now,
      nextReviewAt: now.add(reviewDelay),
    );
    final next = {...?state.value, grammarId: updated};
    state = AsyncData(next);
    await _store.saveGrammarProgress(next);
  }
}
