import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/core/services/volume_service.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/data/models/grammar_study_session.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/grammar/grammar_qa_service.dart';
import 'package:jlpt_practice/features/grammar/grammar_study_session_provider.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';

class GrammarDetailScreen extends ConsumerWidget {
  const GrammarDetailScreen({required this.grammarId, super.key});

  final String grammarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(grammarCatalogProvider);
    return catalog.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
        ),
        body: Center(child: Text(error.toString())),
      ),
      data: (items) {
        final grammar = _findGrammar(items, grammarId);
        if (grammar == null) {
          return Scaffold(
            appBar: AppBar(
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
            ),
            body: Center(child: Text(context.strings('noGrammarResults'))),
          );
        }
        return TrackGrammarStudy(
          key: ValueKey(grammar.id),
          session: GrammarStudySession(
            level: grammar.level,
            part: (grammar.rank - 1) ~/ 10 + 1,
            kind: GrammarStudyKind.detail,
            grammarId: grammar.id,
            title: grammar.title,
            updatedAt: DateTime.now(),
          ),
          child: _GrammarDetails(grammar: grammar),
        );
      },
    );
  }
}

class _GrammarDetails extends ConsumerStatefulWidget {
  const _GrammarDetails({required this.grammar});

  final GrammarPoint grammar;

  @override
  ConsumerState<_GrammarDetails> createState() => _GrammarDetailsState();
}

class _GrammarDetailsState extends ConsumerState<_GrammarDetails> {
  TtsService? _ttsService;
  final _questionController = TextEditingController();
  bool _asking = false;
  String? _answer;
  String? _qaError;

  @override
  void dispose() {
    if (_ttsService != null) unawaited(_ttsService!.stop());
    _questionController.dispose();
    super.dispose();
  }

  void _speak(String text) {
    _ttsService ??= ref.read(ttsServiceProvider);
    unawaited(_ttsService!.speak(text));
  }

  Future<void> _askSuggested(
    GrammarPoint grammar,
    String languageCode,
    String question,
  ) {
    _questionController.text = question;
    return _askQuestion(grammar, languageCode);
  }

  Future<void> _askQuestion(GrammarPoint grammar, String languageCode) async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _qaError = context.strings('offlineQuestionLimit'));
      return;
    }
    setState(() {
      _asking = true;
      _qaError = null;
      _answer = null;
    });
    try {
      final service = await ref.read(grammarQaServiceProvider.future);
      final answer = await service.ask(
        grammar: grammar,
        question: question,
        languageCode: languageCode,
      );
      if (!mounted) return;
      setState(() => _answer = answer);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _qaError = context.strings(
          error is OfflineAiException ? error.key : 'offlineInferenceError',
        ),
      );
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _speakIfAudible(String text) async {
    if (await isSystemVolumeTooLow()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings('lowVolumeBody'))));
      return;
    }
    _speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final grammar = widget.grammar;
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('${grammar.level} · #${grammar.rank}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          Text(
            grammar.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            grammar.localizedSummary(language),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.push('/grammar/tutor/${grammar.id}'),
            icon: const Icon(Icons.auto_awesome),
            label: Text(context.strings('practiceWithAi')),
          ),
          const SizedBox(height: 24),
          _DetailSection(
            title: context.strings('formation'),
            child: SelectableText(
              grammar.localizedFormation(language),
              key: PageStorageKey('${grammar.id}-formation'),
            ),
          ),
          const SizedBox(height: 22),
          _DetailSection(
            title: context.strings('explanation'),
            child: SelectableText(
              grammar.localizedExplanation(language),
              key: PageStorageKey('${grammar.id}-explanation'),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            context.strings('examples'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...grammar.examples.indexed.map(
            (indexed) => _ExampleCard(
              number: indexed.$1 + 1,
              example: indexed.$2,
              language: language,
              onSpeak: () => _speakIfAudible(indexed.$2.japanese),
            ),
          ),
          const SizedBox(height: 26),
          _DetailSection(
            title: context.strings('askAboutThisGrammar'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final suggestion in [
                      context.strings('askSuggestionWhenToUse'),
                      context.strings('askSuggestionMoreExamples'),
                      context.strings('askSuggestionDifference'),
                    ])
                      ActionChip(
                        label: Text(suggestion),
                        onPressed: _asking
                            ? null
                            : () =>
                                  _askSuggested(grammar, language, suggestion),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _questionController,
                  enabled: !_asking,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: context.strings('askAboutThisGrammarHint'),
                  ),
                  onSubmitted: (_) => _askQuestion(grammar, language),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _asking
                      ? null
                      : () => _askQuestion(grammar, language),
                  child: _asking
                      ? Text(context.strings('offlineAnswering'))
                      : Text(context.strings('askButton')),
                ),
                if (_qaError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _qaError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (_answer != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(_answer!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 9),
        child,
      ],
    ),
  );
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.number,
    required this.example,
    required this.language,
    required this.onSpeak,
  });

  final int number;
  final GrammarExample example;
  final String language;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            onTap: onSpeak,
            child: Text(
              '$number. ${example.japanese}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          example.reading,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 7),
        Text(
          example.translation(language),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

GrammarPoint? _findGrammar(List<GrammarPoint> items, String id) {
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
}
