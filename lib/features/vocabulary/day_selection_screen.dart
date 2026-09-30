import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/ads/ad_service.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/day_block_access.dart';
import 'package:jlpt_practice/core/services/cloud_sync_service.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/data/repositories/kanji_repository.dart';
import 'package:jlpt_practice/features/vocabulary/day_selection_skeleton.dart';

/// The course whose days [DaySelectionScreen] lists.
enum StudyCourse {
  vocabulary,
  kanji;

  /// Key under which the course keeps its completed and ad-unlocked days, so
  /// kanji progress never mixes with the level's vocabulary progress.
  String progressKey(String level) => switch (this) {
    StudyCourse.vocabulary => level,
    StudyCourse.kanji => 'kanji-$level',
  };

  String dayRoute(int day) => switch (this) {
    StudyCourse.vocabulary => '/study/day/$day',
    StudyCourse.kanji => '/kanji/day/$day',
  };
}

class DaySelectionScreen extends ConsumerStatefulWidget {
  const DaySelectionScreen({this.course = StudyCourse.vocabulary, super.key});

  final StudyCourse course;

  @override
  ConsumerState<DaySelectionScreen> createState() => _DaySelectionScreenState();
}

class _DaySelectionScreenState extends ConsumerState<DaySelectionScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _lastFocusSignature;
  String? _rewardedLevel;
  Set<int> _rewardedDays = const {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureRewardedDaysLoaded(String level) {
    if (_rewardedLevel == level) return;
    _rewardedLevel = level;
    _rewardedDays = const {};
    DayBlockAccess.rewardedDays(level).then((days) {
      if (!mounted || _rewardedLevel != level) return;
      setState(() => _rewardedDays = days);
    });
  }

  Future<void> _handleDayTap(
    String level,
    int day,
    Set<int> completedDays,
  ) async {
    if (completedDays.contains(day)) {
      if (mounted) context.push(widget.course.dayRoute(day));
      return;
    }

    final strings = context.strings;
    if (!DayBlockAccess.prerequisitesComplete(day, completedDays)) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings('finishPreviousDaysTitle')),
          content: Text(
            strings('finishPreviousDaysBody').replaceAll('{day}', '${day - 1}'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings('ok')),
            ),
          ],
        ),
      );
      return;
    }

    if (!DayBlockAccess.requiresRewardedAd(day) ||
        _rewardedDays.contains(day)) {
      if (mounted) context.push(widget.course.dayRoute(day));
      return;
    }

    final persistedRewardedDays = await DayBlockAccess.rewardedDays(level);
    if (!mounted) return;
    if (persistedRewardedDays.contains(day)) {
      setState(() => _rewardedDays = persistedRewardedDays);
      context.push(widget.course.dayRoute(day));
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings('unlockDaysTitle').replaceAll('{day}', '$day')),
        content: Text(strings('unlockDaysBody').replaceAll('{day}', '$day')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings('cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.ondemand_video_rounded),
            label: Text(strings('watchAd')),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final earned = AdService.enabled ? await AdService.showRewarded() : true;
    if (!earned || !mounted) return;

    await DayBlockAccess.unlockRewardedDay(level, day);
    try {
      await const CloudSyncService().syncAccess();
    } on Object {
      // The local unlock remains available while offline.
    }
    if (!mounted) return;
    setState(() => _rewardedDays = {..._rewardedDays, day});
    context.push(widget.course.dayRoute(day));
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(appControllerProvider);
    final kanjiCatalog = widget.course == StudyCourse.kanji
        ? ref.watch(kanjiCatalogProvider)
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('chooseStudyDay'))),
      body: asyncState.when(
        loading: () => const DaySelectionSkeleton(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          if (kanjiCatalog != null) {
            if (kanjiCatalog.hasError) {
              return Center(child: Text('${kanjiCatalog.error}'));
            }
            if (!kanjiCatalog.hasValue) return const DaySelectionSkeleton();
          }
          final progressKey = widget.course.progressKey(state.selectedLevel);
          _ensureRewardedDaysLoaded(progressKey);
          final itemCount = kanjiCatalog == null
              ? state.selectedVocabulary.length
              : kanjiForLevel(
                  kanjiCatalog.requireValue,
                  state.selectedLevel,
                ).length;
          final dayCount = StudyBatches.count(itemCount, state.dailyGoal);
          final completedDays =
              state.completedStudyDays[progressKey] ?? const <int>{};
          final nextIndex = List.generate(dayCount, (index) => index)
              .indexWhere((index) {
                return !completedDays.contains(index + 1);
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
                              '$itemCount ${context.strings(widget.course == StudyCourse.kanji ? 'kanji' : 'words').toLowerCase()}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${state.dailyGoal} ${context.strings(widget.course == StudyCourse.kanji ? 'kanjiPerDay' : 'wordsPerDay')} · $dayCount ${context.strings('days')}',
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
                            '$progressKey-${state.dailyGoal}-$focusIndex-$columns',
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
                          final isComplete = completedDays.contains(day);
                          final isNext = index == nextIndex;
                          final isLocked = !DayBlockAccess.canStudy(
                            day: day,
                            completedDays: completedDays,
                            rewardedDays: _rewardedDays,
                          );
                          final foreground = isNext
                              ? Theme.of(context).colorScheme.onPrimary
                              : isLocked
                              ? Theme.of(context).colorScheme.onSurfaceVariant
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
                              onTap: () => _handleDayTap(
                                progressKey,
                                day,
                                completedDays,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${context.strings('day')} $day',
                                          maxLines: 1,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(color: foreground),
                                        ),
                                        if (isLocked)
                                          Icon(
                                            Icons.lock_outline_rounded,
                                            size: 16,
                                            color: foreground,
                                          ),
                                      ],
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
