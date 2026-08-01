import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/kana/kana_data.dart';

class KanaChartScreen extends StatelessWidget {
  const KanaChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.strings('kanaChart')),
          bottom: TabBar(
            tabs: [
              Tab(text: context.strings('hiragana')),
              Tab(text: context.strings('katakana')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _KanaGrid(script: KanaScript.hiragana),
            _KanaGrid(script: KanaScript.katakana),
          ],
        ),
      ),
    );
  }
}

class _KanaGrid extends StatelessWidget {
  const _KanaGrid({required this.script});

  final KanaScript script;

  @override
  Widget build(BuildContext context) {
    final kana = KanaCatalog.forScript(script);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: kana.length,
      itemBuilder: (context, index) {
        final item = kana[index];
        return Container(
          key: ValueKey('kana-${item.character}'),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.character,
                style: const TextStyle(fontSize: 34, height: 1.1),
              ),
              const SizedBox(height: 5),
              Text(
                item.romaji,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
