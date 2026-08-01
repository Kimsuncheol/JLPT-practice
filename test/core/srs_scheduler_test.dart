import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/services/srs_scheduler.dart';
import 'package:jlpt_practice/data/models/review_progress.dart';

void main() {
  const scheduler = SrsScheduler();
  final now = DateTime.utc(2026, 7, 30, 12);

  test('new word rated good returns in one day', () {
    final progress = scheduler.schedule(
      vocabularyId: '食べる_たべる',
      jlptLevel: 'N5',
      rating: ReviewRating.good,
      now: now,
    );

    expect(progress.intervalDays, 1);
    expect(progress.nextReviewAt, now.add(const Duration(days: 1)));
    expect(progress.state, LearningState.learning);
    expect(progress.correctCount, 1);
  });

  test('again schedules ten minutes and records a lapse', () {
    final learned = scheduler.schedule(
      vocabularyId: '食べる_たべる',
      jlptLevel: 'N5',
      rating: ReviewRating.easy,
      now: now,
    );
    final progress = scheduler.schedule(
      vocabularyId: '食べる_たべる',
      jlptLevel: 'N5',
      rating: ReviewRating.again,
      current: learned,
      now: now,
    );

    expect(progress.nextReviewAt, now.add(const Duration(minutes: 10)));
    expect(progress.lapseCount, 1);
    expect(progress.state, LearningState.relearning);
    expect(progress.consecutiveCorrectCount, 0);
  });

  test('ease factor remains within limits', () {
    ReviewProgress? progress;
    for (var index = 0; index < 20; index++) {
      progress = scheduler.schedule(
        vocabularyId: '読む_よむ',
        jlptLevel: 'N5',
        rating: ReviewRating.again,
        current: progress,
        now: now,
      );
    }
    expect(progress!.easeFactor, 1.3);

    for (var index = 0; index < 20; index++) {
      progress = scheduler.schedule(
        vocabularyId: '読む_よむ',
        jlptLevel: 'N5',
        rating: ReviewRating.easy,
        current: progress,
        now: now,
      );
    }
    expect(progress!.easeFactor, 3);
  });
}
