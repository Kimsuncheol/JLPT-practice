import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

class LearningLanguageScreen extends ConsumerWidget {
  const LearningLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('learningLanguage'))),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final options = [
            ('system', context.strings('system'), Icons.phone_android_rounded),
            ('en', 'English', Icons.language_rounded),
            ('ko', '한국어', Icons.translate_rounded),
          ];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.size20,
              AppSizes.size12,
              AppSizes.size20,
              AppSizes.size28,
            ),
            itemCount: options.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSizes.space10),
            itemBuilder: (context, index) {
              final option = options[index];
              final selected = state.meaningLanguageMode == option.$1;
              return Material(
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSizes.radius20),
                child: ListTile(
                  minTileHeight: 68,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius20),
                  ),
                  leading: Icon(option.$3),
                  title: Text(
                    option.$2,
                    style: const TextStyle(fontWeight: AppFontWeights.bold700),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded)
                      : null,
                  onTap: () => ref
                      .read(appControllerProvider.notifier)
                      .setMeaningLanguage(option.$1),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
