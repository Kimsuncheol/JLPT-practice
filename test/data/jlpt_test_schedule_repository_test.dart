import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/repositories/jlpt_test_schedule_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads every scheduled JLPT sitting from the CSV asset', () async {
    final schedules = await const JlptTestScheduleRepository().load();

    expect(schedules.length, 50);
    for (final level in ['N1', 'N2', 'N3', 'N4', 'N5']) {
      expect(
        schedules.where((s) => s.level == level).length,
        10,
        reason: '$level should have 10 sittings (2 sessions x 5 years)',
      );
    }
    for (final schedule in schedules) {
      expect(schedule.id, isNotEmpty);
      expect(schedule.displayName, isNotEmpty);
      expect(schedule.year, inInclusiveRange(2021, 2025));
      expect(schedule.examDate.year, schedule.year);
    }

    final ids = schedules.map((s) => s.id).toSet();
    expect(ids.length, schedules.length, reason: 'ids should be unique');
  });
}
