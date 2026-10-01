import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/dashboard/home_tab_provider.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

class LevelsScreen extends ConsumerWidget {
  const LevelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('levels'))),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final descriptions = {
            'N5': context.strings('beginner'),
            'N4': context.strings('elementary'),
            'N3': context.strings('intermediate'),
            'N2': context.strings('upperIntermediate'),
            'N1': context.strings('advanced'),
          };
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.size20,
              AppSizes.size12,
              AppSizes.size20,
              AppSizes.size28,
            ),
            itemCount: descriptions.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSizes.space10),
            itemBuilder: (context, index) {
              final entry = descriptions.entries.elementAt(index);
              final selected = state.selectedLevel == entry.key;
              return Material(
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSizes.radius20),
                child: ListTile(
                  minTileHeight: 76,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius20),
                  ),
                  leading: Container(
                    width: AppSizes.size44,
                    height: AppSizes.size44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: AppFontWeights.extraBold,
                      ),
                    ),
                  ),
                  title: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: AppFontWeights.bold700),
                  ),
                  subtitle: Text(entry.value),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded)
                      : null,
                  onTap: selected
                      ? null
                      : () => _confirmSwitchLevel(context, ref, entry.key),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmSwitchLevel(
    BuildContext context,
    WidgetRef ref,
    String level,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.strings('switchLevelTitle').replaceAll('{level}', level),
        ),
        content: Text(
          context.strings('switchLevelBody').replaceAll('{level}', level),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings('switchLevel')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(appControllerProvider.notifier).setLevel(level);
    if (!context.mounted) return;
    ref.read(homeTabIndexProvider.notifier).select(homeTabDashboard);
    context.go('/home');
  }
}
