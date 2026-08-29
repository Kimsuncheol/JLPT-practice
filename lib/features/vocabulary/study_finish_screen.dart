import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

class StudyFinishScreen extends ConsumerWidget {
  const StudyFinishScreen({required this.day, super.key});

  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.celebration_rounded, size: 42),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      context.strings('studyComplete'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.strings('studyCompleteBody'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _finish(context, ref),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(context.strings('finishSession')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/quiz/day/$day'),
                  icon: const Icon(Icons.quiz_rounded),
                  label: Text(context.strings('startQuiz')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings('finishSessionConfirm')),
        content: Text(context.strings('finishSessionConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings('finish')),
          ),
        ],
      ),
    );
    if (shouldComplete != true || !context.mounted) return;

    final level = ref.read(appControllerProvider).requireValue.selectedLevel;
    await ref
        .read(appControllerProvider.notifier)
        .completeStudySession(level, day);
    if (context.mounted) context.pop();
  }
}
