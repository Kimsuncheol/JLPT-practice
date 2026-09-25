import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/utils/streak_tracker.dart';

void main() {
  test('first activity starts a one-day streak', () {
    final result = recordDailyActivity(
      now: DateTime(2026, 9, 21, 12),
      lastActivityDate: null,
      currentStreak: 0,
      longestStreak: 0,
    );

    expect(result.current, 1);
    expect(result.longest, 1);
    expect(result.date, '2026-09-21');
    expect(result.changed, isTrue);
  });

  test('activity on the next calendar day extends the streak', () {
    final result = recordDailyActivity(
      now: DateTime(2026, 3, 1, 8),
      lastActivityDate: '2026-02-28',
      currentStreak: 4,
      longestStreak: 7,
    );

    expect(result.current, 5);
    expect(result.longest, 7);
    expect(result.changed, isTrue);
  });

  test('a second completion on the same day does not double-count', () {
    final result = recordDailyActivity(
      now: DateTime(2026, 9, 21, 23, 59),
      lastActivityDate: '2026-09-21',
      currentStreak: 3,
      longestStreak: 8,
    );

    expect(result.current, 3);
    expect(result.longest, 8);
    expect(result.changed, isFalse);
  });

  test('activity after a missed calendar day resets the current streak', () {
    final result = recordDailyActivity(
      now: DateTime(2026, 9, 21, 9),
      lastActivityDate: '2026-09-19',
      currentStreak: 6,
      longestStreak: 10,
    );

    expect(result.current, 1);
    expect(result.longest, 10);
    expect(result.changed, isTrue);
  });
}
