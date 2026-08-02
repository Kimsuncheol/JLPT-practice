import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_list_skeleton.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';

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
        widget.level ?? ref.watch(selectedGrammarLevelProvider);
    return Scaffold(
      appBar: AppBar(
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
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                        itemCount: grammar.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = grammar[index];
                          return _GrammarCard(
                            grammar: item,
                            language: language,
                            onTap: () =>
                                context.push('/grammar/detail/${item.id}'),
                          );
                        },
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
    required this.onTap,
  });

  final GrammarPoint grammar;
  final String language;
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
          ],
        ),
      ),
    ),
  );
}
