import 'dart:math';

import 'package:jlpt_practice/data/models/review_progress.dart';

class SrsScheduler {
  const SrsScheduler();

  ReviewProgress schedule({
    required String vocabularyId,
    required String jlptLevel,
    required ReviewRating rating,
    ReviewProgress? current,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final state = current?.state ?? LearningState.newWord;
    var interval = current?.intervalDays ?? 0;
    var ease = current?.easeFactor ?? 2.5;
    var repetitions = current?.repetitionCount ?? 0;
    var lapses = current?.lapseCount ?? 0;
    var correct = current?.correctCount ?? 0;
    var incorrect = current?.incorrectCount ?? 0;
    var consecutive = current?.consecutiveCorrectCount ?? 0;
    late LearningState nextState;
    late Duration delay;

    switch (rating) {
      case ReviewRating.again:
        interval = 10 / 1440;
        lapses++;
        incorrect++;
        consecutive = 0;
        ease = max(1.3, ease - 0.2);
        nextState =
            state == LearningState.newWord || state == LearningState.learning
            ? LearningState.learning
            : LearningState.relearning;
        delay = const Duration(minutes: 10);
      case ReviewRating.hard:
        ease = max(1.3, ease - 0.15);
        correct++;
        consecutive++;
        repetitions++;
        if (state == LearningState.newWord || state == LearningState.learning) {
          interval = 0.5;
          delay = const Duration(hours: 12);
          nextState = LearningState.learning;
        } else {
          interval = max(1, interval * 1.2);
          delay = Duration(minutes: (interval * 1440).round());
          nextState = LearningState.review;
        }
      case ReviewRating.good:
        correct++;
        consecutive++;
        repetitions++;
        if (state == LearningState.newWord) {
          interval = 1;
          nextState = LearningState.learning;
        } else if (state == LearningState.learning ||
            state == LearningState.relearning) {
          interval = 3;
          nextState = LearningState.review;
        } else {
          interval = max(1, interval * ease);
          nextState = LearningState.review;
        }
        delay = Duration(minutes: (interval * 1440).round());
      case ReviewRating.easy:
        correct++;
        consecutive++;
        repetitions++;
        ease = min(3, ease + 0.15);
        if (state == LearningState.newWord) {
          interval = 4;
        } else if (state == LearningState.learning ||
            state == LearningState.relearning) {
          interval = 7;
        } else {
          interval = max(4, interval * ease * 1.3);
        }
        nextState = LearningState.review;
        delay = Duration(minutes: (interval * 1440).round());
    }

    if (interval >= 30 && correct >= 5 && rating != ReviewRating.again) {
      nextState = LearningState.mastered;
    }

    return ReviewProgress(
      vocabularyId: vocabularyId,
      jlptLevel: jlptLevel,
      state: nextState,
      nextReviewAt: timestamp.add(delay),
      intervalDays: interval,
      easeFactor: ease.clamp(1.3, 3),
      repetitionCount: repetitions,
      lapseCount: lapses,
      correctCount: correct,
      incorrectCount: incorrect,
      consecutiveCorrectCount: consecutive,
      lastRating: rating,
      updatedAt: timestamp,
    );
  }
}
