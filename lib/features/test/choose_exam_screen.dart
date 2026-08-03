import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

class ChooseExamScreen extends StatelessWidget {
  const ChooseExamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        children: [
          Text(
            strings('chooseExam'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          _ExamGroup(
            children: [
              _ExamTile(
                icon: Icons.fact_check_rounded,
                title: strings('vocabularyTest'),
                subtitle: strings('n5MockTestSubtitle'),
                onTap: () => context.push('/test/n5'),
              ),
              _ExamTile(
                icon: Icons.headphones_rounded,
                title: strings('listeningTest'),
                subtitle: strings('listeningTestSubtitle'),
                onTap: () => context.push('/test/listening'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExamGroup extends StatelessWidget {
  const _ExamGroup({required this.children});
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

class _ExamTile extends StatelessWidget {
  const _ExamTile({
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
