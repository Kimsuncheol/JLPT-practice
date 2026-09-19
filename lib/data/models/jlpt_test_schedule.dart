class JlptTestSchedule {
  const JlptTestSchedule({
    required this.id,
    required this.year,
    required this.session,
    required this.examDate,
    required this.level,
    required this.displayName,
  });

  final String id;
  final int year;
  final String session;
  final DateTime examDate;
  final String level;
  final String displayName;
}
