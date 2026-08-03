import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/quiz.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

const _kQuestionCount = 10;

class _ListeningItem {
  const _ListeningItem({
    required this.vocabulary,
    required this.choices,
    required this.correctAnswer,
  });

  final Vocabulary vocabulary;
  final List<String> choices;
  final String correctAnswer;
}

class ListeningTestScreen extends ConsumerStatefulWidget {
  const ListeningTestScreen({super.key});

  @override
  ConsumerState<ListeningTestScreen> createState() =>
      _ListeningTestScreenState();
}

class _ListeningTestScreenState extends ConsumerState<ListeningTestScreen> {
  List<_ListeningItem>? _items;
  int _index = 0;
  int _audioPlayedForIndex = -1;
  String? _selected;
  bool _answered = false;
  int _correct = 0;
  final List<String> _incorrectIds = [];
  late final DateTime _startedAt = DateTime.now();
  Timer? _autoAdvanceTimer;
  TtsService? _ttsService;

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    if (_ttsService != null) unawaited(_ttsService!.stop());
    super.dispose();
  }

  void _buildItems(AppState state) {
    if (_items != null) return;
    final random = Random();
    final source =
        state.selectedVocabulary
            .where((item) => item.meaning(state.meaningLanguage).isNotEmpty)
            .toList()
          ..shuffle(random);
    _items = source
        .take(_kQuestionCount)
        .map((item) {
          final correctAnswer = item.meaning(state.meaningLanguage);
          final distractors =
              source
                  .where(
                    (candidate) =>
                        candidate.id != item.id &&
                        candidate.meaning(state.meaningLanguage) !=
                            correctAnswer,
                  )
                  .toList()
                ..shuffle(random);
          final choices = <String>[
            correctAnswer,
            ...distractors
                .take(3)
                .map((word) => word.meaning(state.meaningLanguage)),
          ]..shuffle(random);
          return _ListeningItem(
            vocabulary: item,
            choices: choices,
            correctAnswer: correctAnswer,
          );
        })
        .toList(growable: false);
  }

  void _playAudio(Vocabulary vocabulary) {
    _ttsService ??= ref.read(ttsServiceProvider);
    unawaited(_ttsService!.speak(vocabulary.reading));
  }

  Future<void> _advance() async {
    _autoAdvanceTimer?.cancel();
    final items = _items!;
    if (_index < items.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
      return;
    }
    final result = QuizResult(
      total: items.length,
      correct: _correct,
      duration: DateTime.now().difference(_startedAt),
      incorrectIds: List.unmodifiable(_incorrectIds),
    );
    final questions = items
        .map(
          (item) =>
              QuizQuestion(vocabulary: item.vocabulary, choices: item.choices),
        )
        .toList(growable: false);
    await ref
        .read(appControllerProvider.notifier)
        .recordQuizResult(result, questions);
    if (mounted) context.go('/quiz/result');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    _buildItems(state);
    final items = _items!;
    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: context.pop,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: Center(child: Text(context.strings('noResults'))),
      );
    }
    final item = items[_index];
    final isCorrect = _selected == item.correctAnswer;
    if (_audioPlayedForIndex != _index) {
      _audioPlayedForIndex = _index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playAudio(item.vocabulary);
      });
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(context.strings('listeningTest')),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_index + 1) / items.length,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${_index + 1}/${items.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings('listeningInstruction'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => _playAudio(item.vocabulary),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 34),
                            child: Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.volume_up_rounded,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  context.strings('tapToListen'),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...item.choices.asMap().entries.map((entry) {
                      final choice = entry.value;
                      final selected = _selected == choice;
                      Color? color;
                      IconData? trailing;
                      if (_answered && choice == item.correctAnswer) {
                        color = Theme.of(context).colorScheme.primaryContainer;
                        trailing = Icons.check_circle_rounded;
                      } else if (_answered && selected) {
                        color = Theme.of(context).colorScheme.errorContainer;
                        trailing = Icons.cancel_rounded;
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color:
                              color ??
                              (selected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer
                                  : Theme.of(context).colorScheme.surface),
                          borderRadius: BorderRadius.circular(19),
                          child: InkWell(
                            key: ValueKey('listening_choice_${entry.key}'),
                            onTap: _answered
                                ? null
                                : () {
                                    setState(() {
                                      _selected = choice;
                                      _answered = true;
                                      if (choice == item.correctAnswer) {
                                        _correct++;
                                      } else {
                                        _incorrectIds.add(item.vocabulary.id);
                                      }
                                    });
                                    _autoAdvanceTimer?.cancel();
                                    _autoAdvanceTimer = Timer(
                                      const Duration(milliseconds: 1400),
                                      _advance,
                                    );
                                  },
                            borderRadius: BorderRadius.circular(19),
                            child: Padding(
                              padding: const EdgeInsets.all(17),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                    ),
                                    child: Text(
                                      String.fromCharCode(65 + entry.key),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      choice,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (trailing != null) Icon(trailing),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_answered)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCorrect
                                  ? context.strings('correct')
                                  : context.strings('incorrect'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item.vocabulary.word} · ${item.vocabulary.reading}',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
