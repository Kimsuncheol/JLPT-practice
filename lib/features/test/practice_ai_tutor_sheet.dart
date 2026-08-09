import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/features/test/practice_ai_tutor_service.dart';

Future<void> showPracticeAiTutorSheet({
  required BuildContext context,
  required MockTestProblem problem,
  required String selectedAnswer,
  required String explanationLanguage,
  required VoidCallback onContinue,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: .82,
    child: PracticeAiTutorSheet(
      problem: problem,
      selectedAnswer: selectedAnswer,
      explanationLanguage: explanationLanguage,
      onContinue: onContinue,
    ),
  ),
);

class PracticeAiTutorSheet extends ConsumerStatefulWidget {
  const PracticeAiTutorSheet({
    required this.problem,
    required this.selectedAnswer,
    required this.explanationLanguage,
    required this.onContinue,
    super.key,
  });

  final MockTestProblem problem;
  final String selectedAnswer;
  final String explanationLanguage;
  final VoidCallback onContinue;

  @override
  ConsumerState<PracticeAiTutorSheet> createState() =>
      _PracticeAiTutorSheetState();
}

class _PracticeAiTutorSheetState extends ConsumerState<PracticeAiTutorSheet> {
  PracticeTutorFeedback? _feedback;
  Object? _error;
  bool _loading = true;
  bool _feedbackSent = false;
  PracticeTutorFocus _focus = PracticeTutorFocus.overview;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load([
    PracticeTutorFocus focus = PracticeTutorFocus.overview,
  ]) async {
    setState(() {
      _focus = focus;
      _loading = true;
      _error = null;
    });
    try {
      final evaluator = await ref.read(practiceAiTutorProvider.future);
      final feedback = await evaluator.explain(
        problem: widget.problem,
        selectedAnswer: widget.selectedAnswer,
        explanationLanguage: widget.explanationLanguage,
        focus: focus,
      );
      if (!mounted) return;
      setState(() => _feedback = feedback);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.strings('aiTutor'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
      Expanded(child: _body()),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: FilledButton(
          key: const ValueKey('practice_ai_continue'),
          onPressed: () {
            Navigator.pop(context);
            widget.onContinue();
          },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(context.strings('continue')),
        ),
      ),
    ],
  );

  Widget _body() {
    if (_loading && _feedback == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.strings('askingAiTutor')),
          ],
        ),
      );
    }
    if (_error != null && _feedback == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44),
              const SizedBox(height: 14),
              Text(
                context.strings('aiTutorUnavailable'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _load,
                child: Text(context.strings('tryAgain')),
              ),
            ],
          ),
        ),
      );
    }

    final feedback = _feedback!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      children: [
        _TutorSection(title: null, body: feedback.summary),
        _TutorSection(
          title: context.strings('whyCorrect'),
          body: feedback.whyCorrect,
        ),
        if (feedback.whySelectedIsWrong?.trim().isNotEmpty == true)
          _TutorSection(
            title: context.strings('whyWrong'),
            body: feedback.whySelectedIsWrong!,
          ),
        if (feedback.keyEvidence.isNotEmpty)
          _TutorListSection(
            title: context.strings('keyEvidence'),
            items: feedback.keyEvidence,
            quote: true,
          ),
        if (feedback.learningPoints.isNotEmpty)
          _TutorListSection(
            title: context.strings('learningPoints'),
            items: feedback.learningPoints,
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _focusChip(
              PracticeTutorFocus.choices,
              context.strings('explainChoices'),
            ),
            if (widget.problem.passage.isNotEmpty)
              _focusChip(
                PracticeTutorFocus.evidence,
                context.strings('showEvidence'),
              ),
            _focusChip(
              PracticeTutorFocus.example,
              context.strings('giveExample'),
            ),
          ],
        ),
        if (_loading) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 24),
        Text(
          context.strings('aiGeneratedNotice'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        if (_feedbackSent)
          Text(context.strings('thanksFeedback'))
        else
          Row(
            children: [
              Text(context.strings('wasHelpful')),
              IconButton(
                onPressed: () => setState(() => _feedbackSent = true),
                icon: const Icon(Icons.thumb_up_outlined),
              ),
              IconButton(
                onPressed: () => setState(() => _feedbackSent = true),
                icon: const Icon(Icons.thumb_down_outlined),
              ),
            ],
          ),
      ],
    );
  }

  Widget _focusChip(PracticeTutorFocus focus, String label) => ActionChip(
    label: Text(label),
    avatar: _loading && _focus == focus
        ? const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
    onPressed: _loading ? null : () => _load(focus),
  );
}

class _TutorSection extends StatelessWidget {
  const _TutorSection({required this.title, required this.body});

  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
        ],
        Text(body, style: const TextStyle(height: 1.5)),
      ],
    ),
  );
}

class _TutorListSection extends StatelessWidget {
  const _TutorListSection({
    required this.title,
    required this.items,
    this.quote = false,
  });

  final String title;
  final List<String> items;
  final bool quote;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              quote ? '“$item”' : '• $item',
              style: const TextStyle(height: 1.45),
            ),
          ),
      ],
    ),
  );
}
