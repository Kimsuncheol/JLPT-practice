import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/ads/ad_service.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/data/models/quiz.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/test/mock_test_providers.dart';

const _kN5Level = 'N5';
const _kSectionCount = 10;

class _TestItem {
  const _TestItem({
    required this.type,
    required this.id,
    required this.prompt,
    required this.subPrompt,
    required this.choices,
    required this.correctAnswer,
    required this.hint,
    required this.feedbackLine,
    required this.feedbackDetail,
  });

  final TestSectionType type;
  final String id;
  final String prompt;
  final String subPrompt;
  final List<String> choices;
  final String correctAnswer;
  final String hint;
  final String feedbackLine;
  final String feedbackDetail;
}

class MockTestScreen extends ConsumerStatefulWidget {
  const MockTestScreen({super.key});

  @override
  ConsumerState<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends ConsumerState<MockTestScreen> {
  List<QuizQuestion>? _vocabularyQuestions;
  List<_TestItem>? _items;
  int _index = 0;
  String? _selected;
  bool _answered = false;
  bool _hintRevealed = false;
  final List<String> _incorrectIds = [];
  late final DateTime _startedAt = DateTime.now();
  Timer? _autoAdvanceTimer;

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  void _buildItems(AppState state, List<GrammarPoint> grammarPoints) {
    if (_items != null) return;
    final repository = ref.read(mockTestRepositoryProvider);
    _vocabularyQuestions = repository.buildVocabularySection(
      state.vocabulary,
      level: _kN5Level,
      count: _kSectionCount,
    );
    final grammarQuestions = repository.buildGrammarSection(
      grammarPoints,
      level: _kN5Level,
      language: state.meaningLanguage,
      count: _kSectionCount,
    );
    _items = [
      ..._vocabularyQuestions!.map(
        (question) => _TestItem(
          type: TestSectionType.vocabulary,
          id: question.vocabulary.id,
          prompt: question.vocabulary.example.quizSentence,
          subPrompt: question.vocabulary.example.translation(
            state.meaningLanguage,
          ),
          choices: question.choices,
          correctAnswer: question.correctAnswer,
          hint:
              '${question.vocabulary.reading} · ${question.vocabulary.meaning(state.meaningLanguage)}',
          feedbackLine:
              '${question.vocabulary.reading} · ${question.vocabulary.meaning(state.meaningLanguage)}',
          feedbackDetail: question.vocabulary.example.sentence,
        ),
      ),
      ...grammarQuestions.map(
        (question) => _TestItem(
          type: TestSectionType.grammar,
          id: question.grammarPoint.id,
          prompt: question.grammarPoint.title,
          subPrompt: question.grammarPoint.localizedFormation(
            state.meaningLanguage,
          ),
          choices: question.choices,
          correctAnswer: question.correctAnswer,
          hint: question.grammarPoint.examples.isNotEmpty
              ? question.grammarPoint.examples.first.japanese
              : question.grammarPoint.localizedFormation(
                  state.meaningLanguage,
                ),
          feedbackLine: question.grammarPoint.localizedFormation(
            state.meaningLanguage,
          ),
          feedbackDetail: question.grammarPoint.localizedExplanation(
            state.meaningLanguage,
          ),
        ),
      ),
    ];
  }

  Future<void> _advance() async {
    _autoAdvanceTimer?.cancel();
    final items = _items!;
    if (_index < items.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
        _hintRevealed = false;
      });
      return;
    }
    final sections = <MockTestSectionResult>[];
    for (final type in TestSectionType.values) {
      final typeItems = items.where((item) => item.type == type).toList();
      if (typeItems.isEmpty) continue;
      final ids = typeItems.map((item) => item.id).toSet();
      final sectionIncorrect = _incorrectIds
          .where(ids.contains)
          .toSet()
          .toList(growable: false);
      sections.add(
        MockTestSectionResult(
          type: type,
          total: typeItems.length,
          correct: typeItems.length - sectionIncorrect.length,
          incorrectIds: sectionIncorrect,
        ),
      );
    }
    final result = MockTestResult(
      sections: sections,
      duration: DateTime.now().difference(_startedAt),
    );
    await ref
        .read(appControllerProvider.notifier)
        .recordMockTestResult(
          result,
          vocabularyQuestions: _vocabularyQuestions!,
        );
    if (mounted) context.go('/test/n5/result');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final grammarAsync = ref.watch(grammarCatalogProvider);
    return grammarAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(error.toString())),
      ),
      data: (grammarPoints) {
        _buildItems(state, grammarPoints);
        final items = _items!;
        if (items.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.strings('noResults'))),
          );
        }
        final item = items[_index];
        final isCorrect = _selected == item.correctAnswer;
        final sectionLabel = item.type == TestSectionType.vocabulary
            ? context.strings('sectionVocabulary')
            : context.strings('grammar');
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: context.pop,
              icon: const Icon(Icons.close_rounded),
            ),
            title: Text('${context.strings('n5Test')} · $sectionLabel'),
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
                          item.type == TestSectionType.vocabulary
                              ? context.strings('quizInstruction')
                              : context.strings('grammarQuizInstruction'),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 34,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            children: [
                              Text(
                                item.prompt,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 25,
                                  height: 1.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                item.subPrompt,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!_answered)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () async {
                                if (_hintRevealed) {
                                  setState(() => _hintRevealed = false);
                                  return;
                                }
                                if (AdService.enabled) {
                                  final earned = await AdService.showRewarded();
                                  if (earned && mounted) {
                                    setState(() => _hintRevealed = true);
                                  }
                                } else {
                                  setState(() => _hintRevealed = true);
                                }
                              },
                              icon: Icon(
                                _hintRevealed
                                    ? Icons.lightbulb_rounded
                                    : AdService.enabled
                                    ? Icons.ondemand_video_rounded
                                    : Icons.lightbulb_outline_rounded,
                              ),
                              label: Text(_hintRevealed ? 'Hide Hint' : 'Hint'),
                            ),
                          ),
                        if (_hintRevealed && !_answered)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(item.hint),
                          ),
                        ...item.choices.asMap().entries.map((entry) {
                          final choice = entry.value;
                          final selected = _selected == choice;
                          Color? color;
                          IconData? trailing;
                          if (_answered && choice == item.correctAnswer) {
                            color = Theme.of(
                              context,
                            ).colorScheme.primaryContainer;
                            trailing = Icons.check_circle_rounded;
                          } else if (_answered && selected) {
                            color = Theme.of(
                              context,
                            ).colorScheme.errorContainer;
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
                                key: ValueKey('mock_test_choice_${entry.key}'),
                                onTap: _answered
                                    ? null
                                    : () {
                                        setState(() {
                                          _selected = choice;
                                          _answered = true;
                                          if (choice != item.correctAnswer) {
                                            _incorrectIds.add(item.id);
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
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
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.errorContainer,
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
                                Text(item.feedbackLine),
                                const SizedBox(height: 6),
                                Text(item.feedbackDetail),
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
      },
    );
  }
}
