import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/core/api/jlpt_practice_service.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/test/practice_ai_tutor_screen.dart';

class AiPracticeScreen extends ConsumerStatefulWidget {
  const AiPracticeScreen({required this.level, this.topic, super.key});
  final String level;
  final String? topic;

  @override
  ConsumerState<AiPracticeScreen> createState() => _AiPracticeScreenState();
}

class _AiPracticeScreenState extends ConsumerState<AiPracticeScreen> {
  final _scroll = ScrollController();
  String _category = 'grammar';
  String? _error;
  bool _busy = false;
  List<AiPracticeQuestion>? _questions;
  int _index = 0, _correct = 0;
  int? _selected;
  String _sessionLanguage = 'en';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_busy) return;
    final language =
        ref.read(appControllerProvider).value?.meaningLanguage ??
        Localizations.localeOf(context).languageCode;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final questions =
          await JlptPracticeService(ref.read(jlptApiClientProvider)).generate(
            level: widget.level,
            category: _category,
            language: language,
            topic: widget.topic,
          );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _index = 0;
        _selected = null;
        _correct = 0;
        _sessionLanguage = language;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (error) {
      if (mounted) setState(() => _error = aiErrorKey(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    setState(() {
      _index++;
      _selected = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(jlptApiClientProvider);
    final questions = _questions;
    final done = questions != null && _index >= questions.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.level} · ${context.strings('aiExtraPractice')}'),
      ),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              context.strings('aiPracticeNotice'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (widget.topic != null) ...[
              Text(
                widget.topic!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(context.strings('aiFocusedEnglishNotice')),
            ],
            if (questions == null || done) ...[
              if (done) ...[
                Text(
                  context.strings('mockTestComplete'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text('$_correct / ${questions.length}'),
              ],
              if (widget.topic == null)
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: context.strings('chooseQuestionType'),
                  ),
                  items: [
                    for (final category in ['vocabulary', 'grammar', 'reading'])
                      DropdownMenuItem(
                        value: category,
                        child: Text(
                          context.strings(switch (category) {
                            'vocabulary' => 'sectionVocabulary',
                            'reading' => 'sectionReading',
                            _ => 'grammar',
                          }),
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _category = value!),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('ai_generate_practice'),
                onPressed: _busy ? null : _generate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(context.strings('aiGeneratePractice')),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
              Text(
                context.strings('aiGenerating'),
                textAlign: TextAlign.center,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(context.strings(_error!)),
              TextButton(
                onPressed: _busy ? null : _generate,
                child: Text(context.strings('tryAgain')),
              ),
            ],
            if (questions != null && !done)
              ..._question(questions[_index], questions.length),
          ],
        ),
      ),
    );
  }

  List<Widget> _question(AiPracticeQuestion item, int count) {
    final problem = item.problem;
    final correctIndex = problem.choices.indexOf(problem.correctAnswer);
    return [
      Text('${context.strings('question')} ${_index + 1}/$count'),
      if (problem.passage.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(problem.passage),
        ),
      const SizedBox(height: 12),
      Text(problem.question, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      for (final (index, choice) in problem.choices.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            key: ValueKey('ai_choice_$index'),
            onPressed: _selected != null
                ? null
                : () => setState(() {
                    _selected = index;
                    if (index == correctIndex) _correct++;
                  }),
            child: Text(choice),
          ),
        ),
      if (_selected != null) ...[
        Text(
          context.strings(_selected == correctIndex ? 'correct' : 'incorrect'),
        ),
        Text('${context.strings('answer')}: ${problem.correctAnswer}'),
        const SizedBox(height: 12),
        for (final (index, explanation) in item.explanations.indexed)
          if (widget.topic == null || index == correctIndex)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${problem.choices[index]}: $explanation'),
            ),
        if (item.supportingSentence case final sentence?) Text(sentence),
        FilledButton.tonalIcon(
          onPressed: () => showPracticeAiTutorScreen(
            context: context,
            problem: problem,
            selectedAnswer: problem.choices[_selected!],
            explanationLanguage: explanationLanguage(_sessionLanguage),
            onContinue: _next,
            optionExplanations: item.explanations,
            supportingSentence: item.supportingSentence,
          ),
          icon: const Icon(Icons.school_outlined),
          label: Text(context.strings('askAiTutor')),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('ai_practice_next'),
          onPressed: _next,
          child: Text(
            context.strings(_index + 1 == count ? 'seeResults' : 'next'),
          ),
        ),
      ],
    ];
  }
}
