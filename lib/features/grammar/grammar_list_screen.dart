import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/data/models/grammar_progress.dart';
import 'package:jlpt_practice/features/grammar/grammar_list_skeleton.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_providers.dart';

class GrammarListScreen extends ConsumerStatefulWidget {
  const GrammarListScreen({this.level, super.key});

  final String? level;

  @override
  ConsumerState<GrammarListScreen> createState() => _GrammarListScreenState();
}

class _GrammarListScreenState extends ConsumerState<GrammarListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(grammarCatalogProvider);
    final language = Localizations.localeOf(context).languageCode;
    final selectedLevel =
        (widget.level ?? ref.watch(selectedGrammarLevelProvider))!;
    final progress = ref.watch(grammarProgressProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('$selectedLevel ${context.strings('grammar')}'),
      ),
      body: catalog.when(
        loading: () => const GrammarListSkeleton(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          final grammar = items
              .where(
                (item) => item.level == selectedLevel && item.matches(_query),
              )
              .toList(growable: false);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: context.strings('searchGrammar'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Expanded(
                child: grammar.isEmpty
                    ? Center(child: Text(context.strings('noGrammarResults')))
                    : _query.trim().isNotEmpty
                    ? _SearchResults(
                        grammar: grammar,
                        language: language,
                        progress: progress,
                      )
                    : _PartList(
                        grammar: grammar,
                        language: language,
                        progress: progress,
                        level: selectedLevel,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GrammarCard extends StatelessWidget {
  const _GrammarCard({
    required this.grammar,
    required this.language,
    required this.progress,
    required this.onTap,
  });

  final GrammarPoint grammar;
  final String language;
  final GrammarProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                '${grammar.rank}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grammar.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    grammar.localizedSummary(language),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                _MasteryIcon(progress: progress),
                IconButton(
                  tooltip: context.strings('practiceWithAi'),
                  onPressed: () => context.push('/grammar/tutor/${grammar.id}'),
                  icon: const Icon(Icons.auto_awesome_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PartList extends StatelessWidget {
  const _PartList({
    required this.grammar,
    required this.language,
    required this.progress,
    required this.level,
  });

  final List<GrammarPoint> grammar;
  final String language;
  final Map<String, GrammarProgress> progress;
  final String level;

  @override
  Widget build(BuildContext context) {
    final parts = <int, List<GrammarPoint>>{};
    for (final item in grammar) {
      parts.putIfAbsent(((item.rank - 1) ~/ 10) + 1, () => []).add(item);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: parts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final number = parts.keys.elementAt(index);
        final items = parts[number]!;
        final practised = items
            .where((item) => progress.containsKey(item.id))
            .length;
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            initiallyExpanded: number == 1,
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            title: Text(
              '${context.strings('part')} $number · ${context.strings('ranks')} ${items.first.rank}–${items.last.rank}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$practised ${context.strings('of')} ${items.length} ${context.strings('practised')}',
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: items.isEmpty ? 0 : practised / items.length,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ],
              ),
            ),
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push('/grammar/part/$level/$number'),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    practised == 0
                        ? context.strings('startPartCheckpoint')
                        : context.strings('continueWithAiTutor'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (final item in items) ...[
                _GrammarCard(
                  grammar: item,
                  language: language,
                  progress: progress[item.id],
                  onTap: () => context.push('/grammar/detail/${item.id}'),
                ),
                if (item != items.last) const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.grammar,
    required this.language,
    required this.progress,
  });

  final List<GrammarPoint> grammar;
  final String language;
  final Map<String, GrammarProgress> progress;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
    itemCount: grammar.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final item = grammar[index];
      return _GrammarCard(
        grammar: item,
        language: language,
        progress: progress[item.id],
        onTap: () => context.push('/grammar/detail/${item.id}'),
      );
    },
  );
}

class _MasteryIcon extends StatelessWidget {
  const _MasteryIcon({required this.progress});
  final GrammarProgress? progress;

  @override
  Widget build(BuildContext context) {
    final mastery = progress?.mastery ?? GrammarMastery.newItem;
    final (icon, color) = switch (mastery) {
      GrammarMastery.newItem => (
        Icons.circle_outlined,
        Theme.of(context).colorScheme.outline,
      ),
      GrammarMastery.learning => (Icons.timelapse_rounded, Colors.orange),
      GrammarMastery.familiar => (Icons.check_circle_outline, Colors.blue),
      GrammarMastery.mastered => (Icons.verified_rounded, Colors.green),
    };
    return Tooltip(
      message: context.strings(mastery.name),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
