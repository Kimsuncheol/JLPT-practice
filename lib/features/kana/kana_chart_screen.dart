import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/kana/kana_data.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

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
            _KanaSections(script: KanaScript.hiragana),
            _KanaSections(script: KanaScript.katakana),
          ],
        ),
      ),
    );
  }
}

class _KanaSections extends StatelessWidget {
  const _KanaSections({required this.script});

  final KanaScript script;

  @override
  Widget build(BuildContext context) {
    final groups = KanaCatalog.groups(script);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.size20,
        AppSizes.size22,
        AppSizes.size20,
        AppSizes.size32,
      ),
      itemCount: groups.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSizes.space28),
      itemBuilder: (context, index) => _KanaGroupSection(group: groups[index]),
    );
  }
}

class _KanaGroupSection extends StatelessWidget {
  const _KanaGroupSection({required this.group});

  final KanaGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.strings(group.titleKey),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: AppFontWeights.bold700),
        ),
        if (group.noteKey != null) ...[
          const SizedBox(height: AppSizes.space4),
          Text(
            context.strings(group.noteKey!),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: AppSizes.font13,
            ),
          ),
        ],
        const SizedBox(height: AppSizes.space12),
        _KanaGrid(items: group.items),
      ],
    );
  }
}

class _KanaGrid extends ConsumerWidget {
  const _KanaGrid({required this.items});

  final List<KanaCharacter> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isMultiGlyph = item.character.length > 1;
        return Container(
          key: ValueKey('kana-${item.character}'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radius18),
          ),
          child: Semantics(
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.radius18),
              onTap: () => ref.read(ttsServiceProvider).speak(item.character),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.character,
                    style: TextStyle(
                      fontSize: isMultiGlyph ? 24 : 34,
                      height: AppSizes.lineHeight1_1,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space5),
                  Text(
                    item.romaji,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: AppSizes.font12,
                      fontWeight: AppFontWeights.semiBold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
