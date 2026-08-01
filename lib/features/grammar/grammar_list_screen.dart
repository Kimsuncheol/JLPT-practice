import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';

class GrammarListScreen extends ConsumerStatefulWidget {
  const GrammarListScreen({required this.level, super.key});

  final String level;

  @override
  ConsumerState<GrammarListScreen> createState() => _GrammarListScreenState();
}

class _GrammarListScreenState extends ConsumerState<GrammarListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(grammarCatalogProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.level} ${context.strings('grammar')}'),
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          final grammar = items
              .where(
                (item) => item.level == widget.level && item.matches(_query),
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
                        itemBuilder: (context, index) =>
                            _GrammarCard(grammar: grammar[index]),
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
  const _GrammarCard({required this.grammar});

  final GrammarPoint grammar;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: PageStorageKey(grammar.id),
      leading: CircleAvatar(
        child: Text(
          '${grammar.rank}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
      title: Text(
        grammar.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(grammar.summary),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 28),
              _Section(
                title: context.strings('formation'),
                child: SelectableText(grammar.formation),
              ),
              const SizedBox(height: 18),
              _Section(
                title: context.strings('explanation'),
                child: SelectableText(grammar.explanation),
              ),
              const SizedBox(height: 20),
              Text(
                context.strings('examples'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              ...grammar.examples.indexed.map(
                (indexed) =>
                    _ExampleCard(number: indexed.$1 + 1, example: indexed.$2),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 7),
      child,
    ],
  );
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.number, required this.example});

  final int number;
  final GrammarExample example;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. ${example.japanese}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(example.romaji),
        const SizedBox(height: 6),
        Text(
          example.english,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
