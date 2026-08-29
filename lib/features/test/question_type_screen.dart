import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';

class QuestionTypeScreen extends StatelessWidget {
  const QuestionTypeScreen({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final basePath = '/test/practice/$level';

    return Scaffold(
      appBar: AppBar(title: Text('$level ${strings('practiceTest')}')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            Text(
              strings('chooseQuestionType'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            _QuestionTypeGroup(
              children: [
                _QuestionTypeTile(
                  icon: Icons.menu_book_rounded,
                  title: strings('sectionReading'),
                  subtitle: strings('readingComprehension'),
                  onTap: () => context.push(
                    '$basePath/${sectionPathSegment(ProblemSection.reading)}',
                  ),
                ),
                _QuestionTypeTile(
                  icon: Icons.headphones_rounded,
                  title: strings('sectionListening'),
                  subtitle: strings('listeningComprehension'),
                  onTap: () => context.push(
                    '$basePath/${sectionPathSegment(ProblemSection.listening)}',
                  ),
                ),
                _QuestionTypeTile(
                  icon: Icons.spellcheck_rounded,
                  title: strings('grammar'),
                  subtitle: strings('languageKnowledgeGrammar'),
                  onTap: () => context.push(
                    '$basePath/${sectionPathSegment(ProblemSection.grammar)}',
                  ),
                ),
                _QuestionTypeTile(
                  icon: Icons.fact_check_rounded,
                  title: strings('sectionVocabulary'),
                  subtitle: strings('languageKnowledgeVocabulary'),
                  onTap: () => context.push(
                    '$basePath/${sectionPathSegment(ProblemSection.vocabulary)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionTypeGroup extends StatelessWidget {
  const _QuestionTypeGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(
              height: 1,
              indent: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
        ],
      ],
    ),
  );
}

class _QuestionTypeTile extends StatelessWidget {
  const _QuestionTypeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    leading: Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
