import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/test/mock_test_providers.dart';

class LevelPracticeTestScreen extends ConsumerWidget {
  const LevelPracticeTestScreen({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final schedulesAsync = ref.watch(jlptTestSchedulesForLevelProvider(level));
    return Scaffold(
      appBar: AppBar(title: Text('$level ${strings('practiceTest')}')),
      body: SafeArea(
        top: false,
        child: schedulesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (schedules) {
            if (schedules.isEmpty) {
              return Center(child: Text(strings('noResults')));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              itemCount: schedules.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final schedule = schedules[index];
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
                      child: const Icon(Icons.event_rounded),
                    ),
                    title: Text(
                      schedule.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${schedule.examDate.year}-${schedule.examDate.month.toString().padLeft(2, '0')}-${schedule.examDate.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        context.push('/test/practice/$level/${schedule.id}'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
