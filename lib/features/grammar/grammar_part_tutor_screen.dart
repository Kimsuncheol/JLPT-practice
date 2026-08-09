import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/immersive_study_mode.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_providers.dart';

class GrammarPartTutorScreen extends ConsumerStatefulWidget {
  const GrammarPartTutorScreen({
    required this.level,
    required this.part,
    super.key,
  });

  final String level;
  final int part;

  @override
  ConsumerState<GrammarPartTutorScreen> createState() =>
      _GrammarPartTutorScreenState();
}

class _GrammarPartTutorScreenState extends ConsumerState<GrammarPartTutorScreen>
    with ImmersiveStudyMode<GrammarPartTutorScreen> {
  int _index = 0;
  String? _selected;
  final Map<String, bool> _results = {};
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(grammarCatalogProvider);
    return wrapImmersive(
      catalog.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
        data: (allItems) {
          final start = (widget.part - 1) * 10 + 1;
          final end = widget.part * 10;
          final partItems =
              allItems
                  .where(
                    (item) =>
                        item.level == widget.level &&
                        item.rank >= start &&
                        item.rank <= end,
                  )
                  .toList()
                ..sort((a, b) => a.rank.compareTo(b.rank));
          if (partItems.isEmpty) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(context.strings('noGrammarResults'))),
            );
          }
          final questions = _selectQuestions(partItems);
          return _buildCheckpoint(questions, partItems);
        },
      ),
    );
  }

  List<GrammarPoint> _selectQuestions(List<GrammarPoint> partItems) {
    final progress = ref.watch(grammarProgressProvider).value ?? const {};
    final sorted = [...partItems]
      ..sort((a, b) {
        final aProgress = progress[a.id];
        final bProgress = progress[b.id];
        if (aProgress == null && bProgress != null) return -1;
        if (aProgress != null && bProgress == null) return 1;
        if (aProgress != null && bProgress != null) {
          return aProgress.accuracy.compareTo(bProgress.accuracy);
        }
        return a.rank.compareTo(b.rank);
      });
    return sorted.take(5).toList(growable: false);
  }

  Widget _buildCheckpoint(
    List<GrammarPoint> questions,
    List<GrammarPoint> partItems,
  ) {
    final complete = _index >= questions.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.level} · ${context.strings('part')} ${widget.part}',
        ),
      ),
      body: SafeArea(
        top: false,
        child: complete
            ? _resultsView(questions)
            : _questionView(questions, partItems),
      ),
    );
  }

  Widget _questionView(
    List<GrammarPoint> questions,
    List<GrammarPoint> partItems,
  ) {
    final grammar = questions[_index];
    final language = Localizations.localeOf(context).languageCode;
    final distractors = partItems
        .where((item) => item.id != grammar.id)
        .take(2)
        .toList();
    final choices = [grammar, ...distractors]
      ..sort((a, b) => a.title.compareTo(b.title));
    final correct = _selected == grammar.id;
    return Column(
      children: [
        LinearProgressIndicator(value: (_index + 1) / questions.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${context.strings('question')} ${_index + 1}/${questions.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                grammar.localizedSummary(language),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              for (final choice in choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    onPressed: _selected == null
                        ? () => setState(() {
                            _selected = choice.id;
                            _results[grammar.id] = choice.id == grammar.id;
                          })
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(18),
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text('#${choice.rank}  ${choice.title}'),
                  ),
                ),
              if (_selected != null) ...[
                const SizedBox(height: 8),
                Text(
                  context.strings(correct ? 'correct' : 'incorrect'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: correct
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                if (!correct) ...[
                  const SizedBox(height: 6),
                  Text('${context.strings('answer')}: ${grammar.title}'),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => setState(() {
                    _index++;
                    _selected = null;
                  }),
                  child: Text(
                    _index == questions.length - 1
                        ? context.strings('seeResults')
                        : context.strings('next'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultsView(List<GrammarPoint> questions) {
    if (!_saved) {
      _saved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        for (final item in questions) {
          await ref
              .read(grammarProgressProvider.notifier)
              .record(
                grammarId: item.id,
                correct: _results[item.id] == true ? 1 : 0,
                attempts: 1,
                mistake: _results[item.id] == true
                    ? null
                    : context.strings('meaningNotRecognized'),
              );
        }
      });
    }
    final weak = questions.where((item) => _results[item.id] != true).toList();
    final strong = questions
        .where((item) => _results[item.id] == true)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(
          Icons.insights_rounded,
          size: 58,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          context.strings('checkpointComplete'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 22),
        _ResultGroup(
          title: context.strings('strong'),
          icon: Icons.check_circle_outline,
          items: strong,
        ),
        const SizedBox(height: 14),
        _ResultGroup(
          title: context.strings('reviewNext'),
          icon: Icons.refresh_rounded,
          items: weak,
          onTap: (item) => context.push('/grammar/tutor/${item.id}'),
        ),
        const SizedBox(height: 22),
        if (weak.isNotEmpty)
          FilledButton(
            onPressed: () => context.push('/grammar/tutor/${weak.first.id}'),
            child: Text(context.strings('practiceWeakPoints')),
          ),
        TextButton(
          onPressed: () => context.pop(),
          child: Text(context.strings('finish')),
        ),
      ],
    );
  }
}

class _ResultGroup extends StatelessWidget {
  const _ResultGroup({
    required this.title,
    required this.icon,
    required this.items,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final List<GrammarPoint> items;
  final ValueChanged<GrammarPoint>? onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty) Text(context.strings('none')),
        for (final item in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('#${item.rank}  ${item.title}'),
            trailing: onTap == null ? null : const Icon(Icons.chevron_right),
            onTap: onTap == null ? null : () => onTap!(item),
          ),
      ],
    ),
  );
}
