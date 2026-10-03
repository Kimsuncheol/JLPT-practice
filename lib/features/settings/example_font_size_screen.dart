import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/vocabulary/example_furigana_text.dart';

/// Sets the size of example sentences; their furigana follows it.
class ExampleFontSizeScreen extends ConsumerWidget {
  const ExampleFontSizeScreen({super.key});

  static const _step = 0.1;
  static const _sample = '{私|わたし}は{毎日|まいにち}{日本語|にほんご}を{勉強|べんきょう}します。';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('exampleFontSize'))),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final controller = ref.read(appControllerProvider.notifier);
          final strings = context.strings;
          final colors = Theme.of(context).colorScheme;
          final percent = '${(state.exampleFontScale * 100).round()}%';
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.size20,
              AppSizes.size12,
              AppSizes.size20,
              AppSizes.size28,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.size4,
                  0,
                  AppSizes.size4,
                  AppSizes.size14,
                ),
                child: Text(
                  strings('exampleFontSizeHint'),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radius22),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.size20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ExampleFuriganaText(
                      key: const ValueKey('example-font-preview'),
                      segments: parseFurigana(_sample),
                      style:
                          Theme.of(context).textTheme.titleLarge ??
                          const TextStyle(fontSize: AppSizes.font22),
                      wordTargets: const [],
                      hideReadings: false,
                      alignment: WrapAlignment.start,
                      fontScale: state.exampleFontScale,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.space16),
              Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radius22),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.size20,
                    AppSizes.size16,
                    AppSizes.size20,
                    AppSizes.size8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(strings('exampleFontSize'))),
                          Text(
                            percent,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                      Slider(
                        value: state.exampleFontScale,
                        min: AppState.minExampleFontScale,
                        max: AppState.maxExampleFontScale,
                        divisions:
                            ((AppState.maxExampleFontScale -
                                        AppState.minExampleFontScale) /
                                    _step)
                                .round(),
                        label: percent,
                        semanticFormatterCallback: (value) =>
                            '${strings('exampleFontSize')} ${(value * 100).round()}%',
                        onChanged: controller.setExampleFontScale,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
