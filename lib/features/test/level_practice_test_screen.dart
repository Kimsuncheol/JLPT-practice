import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/features/test/practice_test_generator.dart';

class LevelPracticeTestScreen extends StatelessWidget {
  const LevelPracticeTestScreen({
    super.key,
    required this.level,
    required this.section,
  });

  final String level;
  final ProblemSection section;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final sectionLabel = switch (section) {
      ProblemSection.vocabulary => strings('sectionVocabulary'),
      ProblemSection.grammar => strings('grammar'),
      ProblemSection.reading => strings('sectionReading'),
      ProblemSection.listening => strings('sectionListening'),
    };
    return Scaffold(
      appBar: AppBar(title: Text('$level · $sectionLabel')),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          itemCount: 10,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final practiceNumber = index + 1;
            return Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '$practiceNumber',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(
                  '${strings('practice')} $practiceNumber',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(strings('combinedQuestionPool')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(
                  '/test/practice/$level/${sectionPathSegment(section)}/'
                  '${practiceSetId(practiceNumber)}',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
