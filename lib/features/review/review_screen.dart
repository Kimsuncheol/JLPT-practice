import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/review_progress.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/shared/empty_state.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<Vocabulary>? _queue;
  int _index = 0;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    _queue ??= [
      ...state.dueVocabulary,
      ...state.selectedVocabulary
          .where((word) => !state.progress.containsKey(word.id))
          .take(state.dailyGoal),
    ];
    final queue = _queue!;
    if (queue.isEmpty || _index >= queue.length) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: context.pop,
            icon: const Icon(Icons.close_rounded),
          ),
          title: Text(context.strings('reviewTitle')),
        ),
        body: EmptyState(
          icon: Icons.done_all_rounded,
          title: context.strings('queueComplete'),
          body: context.strings('queueCompleteBody'),
          action: FilledButton(
            onPressed: () => context.go('/home'),
            child: Text(context.strings('backHome')),
          ),
        ),
      );
    }
    final word = queue[_index];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(context.strings('reviewTitle')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                '${_index + 1}/${queue.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: GestureDetector(
                  onTap: () => setState(() => _revealed = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: _revealed
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          word.word,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_revealed) ...[
                          Text(
                            word.reading,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            word.meaning(state.meaningLanguage),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 30),
                          Text(
                            word.example.sentence,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            word.example.translation(state.meaningLanguage),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          const SizedBox(height: 30),
                          const Icon(Icons.touch_app_rounded, size: 30),
                          const SizedBox(height: 10),
                          Text(context.strings('tapReveal')),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_revealed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Row(
                  children: ReviewRating.values.map((rating) {
                    final label = context.strings(rating.name);
                    final colors = [
                      Theme.of(context).colorScheme.errorContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.tertiaryContainer,
                    ];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilledButton(
                          onPressed: () async {
                            await ref
                                .read(appControllerProvider.notifier)
                                .rateVocabulary(word.id, rating);
                            if (mounted) {
                              setState(() {
                                _index++;
                                _revealed = false;
                              });
                            }
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            backgroundColor: colors[rating.index],
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface,
                          ),
                          child: Text(label),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
