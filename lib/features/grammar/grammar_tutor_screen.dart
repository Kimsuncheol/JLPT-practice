import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/immersive_study_mode.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_ai_service.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_models.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_providers.dart';

class GrammarTutorScreen extends ConsumerStatefulWidget {
  const GrammarTutorScreen({required this.grammarId, super.key});

  final String grammarId;

  @override
  ConsumerState<GrammarTutorScreen> createState() => _GrammarTutorScreenState();
}

class _GrammarTutorScreenState extends ConsumerState<GrammarTutorScreen>
    with ImmersiveStudyMode<GrammarTutorScreen> {
  final _sentenceController = TextEditingController();
  int _step = 0;
  int _correct = 0;
  bool? _lastCorrect;
  bool _evaluating = false;
  bool _saved = false;
  GrammarTutorFeedback? _feedback;
  String? _error;

  @override
  void dispose() {
    _sentenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(grammarCatalogProvider);
    return catalog.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (items) {
        final grammar = items.where((item) => item.id == widget.grammarId);
        if (grammar.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.strings('noGrammarResults'))),
          );
        }
        return _buildLesson(grammar.first, items);
      },
    );
  }

  Widget _buildLesson(GrammarPoint grammar, List<GrammarPoint> catalog) {
    final language = Localizations.localeOf(context).languageCode;
    final part = grammarPartForRank(grammar.rank);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${context.strings('part')} ${part.number} · #${grammar.rank}',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / 5),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                children: [
                  _LessonHeader(grammar: grammar, step: _step),
                  const SizedBox(height: 20),
                  switch (_step) {
                    0 => _understandStep(grammar, language),
                    1 => _meaningStep(grammar, catalog, language),
                    2 => _exampleStep(grammar, catalog),
                    3 => _productionStep(grammar),
                    _ => _resultStep(grammar),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _understandStep(GrammarPoint grammar, String language) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _LessonCard(
        icon: Icons.lightbulb_outline_rounded,
        title: context.strings('meaning'),
        child: Text(grammar.localizedExplanation(language)),
      ),
      const SizedBox(height: 14),
      _LessonCard(
        icon: Icons.account_tree_outlined,
        title: context.strings('formation'),
        child: Text(grammar.localizedFormation(language)),
      ),
      const SizedBox(height: 22),
      FilledButton(
        onPressed: () => setState(() => _step = 1),
        child: Text(context.strings('checkUnderstanding')),
      ),
    ],
  );

  Widget _meaningStep(
    GrammarPoint grammar,
    List<GrammarPoint> catalog,
    String language,
  ) {
    final choices = _nearbyGrammar(
      grammar,
      catalog,
    ).map((item) => item.localizedSummary(language)).toList();
    return _QuestionCard(
      question: context.strings('chooseGrammarMeaning'),
      choices: choices,
      correctChoice: grammar.localizedSummary(language),
      enabled: _lastCorrect == null,
      onChoice: (choice) =>
          _answer(choice == grammar.localizedSummary(language)),
      feedback: _answerFeedback(),
      onNext: _lastCorrect == null ? null : _next,
    );
  }

  Widget _exampleStep(GrammarPoint grammar, List<GrammarPoint> catalog) {
    final candidates = _nearbyGrammar(
      grammar,
      catalog,
    ).where((item) => item.examples.isNotEmpty).toList();
    final correctExample = grammar.examples.isEmpty
        ? grammar.title
        : grammar.examples.first.japanese;
    final choices = <String>[
      correctExample,
      ...candidates
          .where((item) => item.id != grammar.id)
          .take(2)
          .map((item) => item.examples.first.japanese),
    ];
    return _QuestionCard(
      question: context.strings('chooseGrammarExample'),
      choices: choices,
      correctChoice: correctExample,
      enabled: _lastCorrect == null,
      onChoice: (choice) => _answer(choice == correctExample),
      feedback: _answerFeedback(),
      onNext: _lastCorrect == null ? null : _next,
    );
  }

  Widget _productionStep(GrammarPoint grammar) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.strings('writeOwnSentence'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(context.strings('useTargetGrammar')),
      const SizedBox(height: 16),
      TextField(
        controller: _sentenceController,
        enabled: !_evaluating,
        minLines: 3,
        maxLines: 5,
        autofocus: true,
        decoration: InputDecoration(
          hintText: grammar.examples.isEmpty
              ? grammar.title
              : grammar.examples.first.japanese,
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _evaluating ? null : () => _evaluate(grammar),
        icon: _evaluating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(context.strings('checkWithAi')),
      ),
    ],
  );

  Widget _resultStep(GrammarPoint grammar) {
    final feedback = _feedback;
    if (!_saved) {
      _saved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(grammarProgressProvider.notifier)
            .record(
              grammarId: grammar.id,
              correct: _correct + (feedback?.score == 2 ? 1 : 0),
              attempts: 3,
              productionScore: feedback?.score ?? 0,
              mistake: feedback?.isCorrect == false ? feedback?.feedback : null,
            );
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          feedback?.isCorrect == true
              ? Icons.celebration_rounded
              : Icons.school_rounded,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 14),
        Text(
          context.strings('lessonComplete'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        if (feedback != null)
          _LessonCard(
            icon: Icons.auto_awesome,
            title: context.strings('aiFeedback'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feedback.feedback),
                if (feedback.correctedSentence.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    feedback.correctedSentence,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => context.pop(),
          child: Text(context.strings('finish')),
        ),
        TextButton(
          onPressed: () => setState(() {
            _step = 0;
            _correct = 0;
            _lastCorrect = null;
            _feedback = null;
            _saved = false;
            _sentenceController.clear();
          }),
          child: Text(context.strings('practiceAgain')),
        ),
      ],
    );
  }

  void _answer(bool correct) {
    setState(() {
      _lastCorrect = correct;
      if (correct) _correct++;
    });
  }

  Widget? _answerFeedback() => _lastCorrect == null
      ? null
      : Text(
          context.strings(_lastCorrect! ? 'correct' : 'incorrect'),
          style: TextStyle(
            color: _lastCorrect!
                ? Colors.green
                : Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        );

  void _next() => setState(() {
    _step++;
    _lastCorrect = null;
  });

  Future<void> _evaluate(GrammarPoint grammar) async {
    final sentence = _sentenceController.text.trim();
    if (sentence.isEmpty) {
      setState(() => _error = context.strings('enterSentence'));
      return;
    }
    setState(() {
      _evaluating = true;
      _error = null;
    });
    final language = Localizations.localeOf(context).languageCode == 'ko'
        ? 'Korean'
        : 'English';
    try {
      final evaluator = await ref.read(grammarTutorEvaluatorProvider.future);
      final feedback = await evaluator.evaluate(
        grammar: grammar,
        sentence: sentence,
        explanationLanguage: language,
      );
      if (!mounted) return;
      setState(() {
        _feedback = feedback;
        _step = 4;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.strings('aiFeedbackError'));
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }
}

List<GrammarPoint> _nearbyGrammar(
  GrammarPoint target,
  List<GrammarPoint> catalog,
) {
  final sameLevel =
      catalog
          .where((item) => item.level == target.level && item.id != target.id)
          .toList()
        ..sort((a, b) {
          final distanceA = (a.rank - target.rank).abs();
          final distanceB = (b.rank - target.rank).abs();
          return distanceA.compareTo(distanceB);
        });
  return [target, ...sameLevel.take(2)]
    ..sort((a, b) => a.title.compareTo(b.title));
}

class _LessonHeader extends StatelessWidget {
  const _LessonHeader({required this.grammar, required this.step});
  final GrammarPoint grammar;
  final int step;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.strings(
          ['understand', 'recognize', 'apply', 'produce', 'result'][step],
        ),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(height: 6),
      Text(grammar.title, style: Theme.of(context).textTheme.headlineSmall),
    ],
  );
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.choices,
    required this.correctChoice,
    required this.enabled,
    required this.onChoice,
    required this.feedback,
    required this.onNext,
  });
  final String question;
  final List<String> choices;
  final String correctChoice;
  final bool enabled;
  final ValueChanged<String> onChoice;
  final Widget? feedback;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(question, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      for (final choice in choices)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            onPressed: enabled ? () => onChoice(choice) : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
            ),
            child: Text(choice),
          ),
        ),
      if (feedback != null) ...[feedback!, const SizedBox(height: 12)],
      if (onNext != null)
        FilledButton(onPressed: onNext, child: Text(context.strings('next'))),
    ],
  );
}
