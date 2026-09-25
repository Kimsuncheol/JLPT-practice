class StreakUpdate {
  const StreakUpdate({
    required this.current,
    required this.longest,
    required this.date,
    required this.changed,
  });

  final int current;
  final int longest;
  final String date;
  final bool changed;
}

StreakUpdate recordDailyActivity({
  required DateTime now,
  required String? lastActivityDate,
  required int currentStreak,
  required int longestStreak,
}) {
  final today = _dateKey(now);
  if (lastActivityDate == today) {
    return StreakUpdate(
      current: currentStreak,
      longest: longestStreak,
      date: today,
      changed: false,
    );
  }

  final previousCalendarDay = DateTime(now.year, now.month, now.day - 1);
  final nextCurrent = lastActivityDate == _dateKey(previousCalendarDay)
      ? currentStreak + 1
      : 1;
  return StreakUpdate(
    current: nextCurrent,
    longest: nextCurrent > longestStreak ? nextCurrent : longestStreak,
    date: today,
    changed: true,
  );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
