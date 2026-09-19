import 'dart:io';

import 'package:jlpt_practice/data/models/jlpt_exam_blueprint.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/repositories/csv_utils.dart';

void main() {
  const path = 'assets/data/jlpt_ranked_mock_questions.csv';
  final rows = parseCsvRows(File(path).readAsStringSync());
  if (rows.isEmpty) throw StateError('Ranked mock bank is empty.');
  final cell = csvCellReader(rows.first);
  var failed = false;

  for (final level in ['N1', 'N2', 'N3', 'N4', 'N5']) {
    stdout.writeln(level);
    // Vocabulary and grammar are generated from ranked catalogs at runtime.
    for (final section in [ProblemSection.reading, ProblemSection.listening]) {
      final expected = blueprintParts(level, section);
      final counts = <int, int>{};
      for (final row in rows.skip(1)) {
        if (cell(row, 'level') != level ||
            cell(row, 'section') != section.name) {
          continue;
        }
        final part = int.tryParse(cell(row, 'part')) ?? 0;
        counts[part] = (counts[part] ?? 0) + 1;
      }
      final missing = expected
          .where((part) => (counts[part.number] ?? 0) == 0)
          .map((part) => part.number)
          .toList();
      failed |= missing.isNotEmpty;
      final coverage = expected
          .map((part) => '${part.number}:${counts[part.number] ?? 0}')
          .join(', ');
      stdout.writeln(
        '  ${section.name.padRight(10)} $coverage'
        '${missing.isEmpty ? '' : '  MISSING $missing'}',
      );
    }
  }
  if (failed) exitCode = 1;
}
