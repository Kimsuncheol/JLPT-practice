import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/features/vocabulary/day_selection_skeleton.dart';

class DaySelectionScreen extends ConsumerStatefulWidget {
  const DaySelectionScreen({super.key});

  @override
  ConsumerState<DaySelectionScreen> createState() => _DaySelectionScreenState();
}

class _DaySelectionScreenState extends ConsumerState<DaySelectionScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _lastFocusSignature;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('chooseStudyDay'))),
      body: asyncState.when(
        loading: () => const DaySelectionSkeleton(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final words = state.selectedVocabulary;
          final dayCount = StudyBatches.count(words.length, state.dailyGoal);
          final completedByDay = List.generate(dayCount, (index) {
            final batch = StudyBatches.wordsForDay(
              words,
              day: index + 1,
              dailyGoal: state.dailyGoal,
            );
            return batch
                .where((word) => state.progress.containsKey(word.id))
                .length;
          });
          final nextIndex = List.generate(dayCount, (index) => index)
              .indexWhere((index) {
                final batchLength = StudyBatches.wordsForDay(
                  words,
                  day: index + 1,
                  dailyGoal: state.dailyGoal,
                ).length;
                return completedByDay[index] < batchLength;
              });
          final focusIndex = nextIndex >= 0
              ? nextIndex
              : math.max(0, dayCount - 1);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          state.selectedLevel,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${words.length} ${context.strings('words').toLowerCase()}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${state.dailyGoal} ${context.strings('wordsPerDay')} · $dayCount ${context.strings('days')}',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 12.0;
                      final columns = math.max(
                        4,
                        math.min(6, (constraints.maxWidth / 120).floor()),
                      );
                      final cardSize =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                      _scheduleNextDayFocus(
                        signature:
                            '${state.selectedLevel}-${state.dailyGoal}-$focusIndex-$columns',
                        focusIndex: focusIndex,
                        columns: columns,
                        cardSize: cardSize,
                        viewportHeight: constraints.maxHeight,
                      );
                      return GridView.builder(
                        controller: _scrollController,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                        ),
                        itemCount: dayCount,
                        itemBuilder: (context, index) {
                          final day = index + 1;
                          final batchLength = StudyBatches.wordsForDay(
                            words,
                            day: day,
                            dailyGoal: state.dailyGoal,
                          ).length;
                          final isComplete =
                              completedByDay[index] == batchLength;
                          final isNext = index == nextIndex;
                          final foreground = isNext
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface;
                          return Material(
                            color: isNext
                                ? Theme.of(context).colorScheme.primary
                                : isComplete
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => context.push('/study/day/$day'),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${context.strings('day')} $day',
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(color: foreground),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _scheduleNextDayFocus({
    required String signature,
    required int focusIndex,
    required int columns,
    required double cardSize,
    required double viewportHeight,
  }) {
    if (_lastFocusSignature == signature) return;
    _lastFocusSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      const spacing = 12.0;
      final row = focusIndex ~/ columns;
      final desired =
          row * (cardSize + spacing) - (viewportHeight - cardSize) / 2;
      final target = desired.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }
}
