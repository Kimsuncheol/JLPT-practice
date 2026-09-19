import 'package:flutter/services.dart';
import 'package:jlpt_practice/data/models/jlpt_test_schedule.dart';
import 'package:jlpt_practice/data/repositories/csv_utils.dart';

class JlptTestScheduleRepository {
  const JlptTestScheduleRepository();

  Future<List<JlptTestSchedule>> load() async {
    final raw = await rootBundle.loadString(
      'assets/data/jlpt_test_schedule_2021_2025.csv',
    );
    final rows = parseCsvRows(raw);
    if (rows.isEmpty) return const [];
    final cell = csvCellReader(rows.first);

    return rows
        .skip(1)
        .map(
          (row) => JlptTestSchedule(
            id: cell(row, 'id'),
            year: int.tryParse(cell(row, 'year')) ?? 0,
            session: cell(row, 'session'),
            examDate: DateTime.tryParse(cell(row, 'exam_date')) ?? DateTime(0),
            level: cell(row, 'level'),
            displayName: cell(row, 'display_name'),
          ),
        )
        .toList(growable: false);
  }
}
