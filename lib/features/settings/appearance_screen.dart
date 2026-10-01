import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('appearance'))),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          const options = [
            (ThemeMode.system, Icons.brightness_auto_rounded),
            (ThemeMode.light, Icons.light_mode_rounded),
            (ThemeMode.dark, Icons.dark_mode_rounded),
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
              final colorScheme = Theme.of(context).colorScheme;
              final option = options[index];
              final selected = state.themeMode == option.$1;
              final foreground = selected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface;
              return Material(
                color: selected
                    ? colorScheme.primaryContainer
                    : colorScheme.surface,
                animationDuration: Duration.zero,
                borderRadius: BorderRadius.circular(AppSizes.radius20),
                child: ListTile(
                  minTileHeight: 68,
                  textColor: foreground,
                  iconColor: foreground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius20),
                  ),
                  leading: Icon(option.$2),
                  title: Text(
                    context.strings(option.$1.name),
                    style: const TextStyle(fontWeight: AppFontWeights.bold700),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded)
                      : null,
                  onTap: () => ref
                      .read(appControllerProvider.notifier)
                      .setThemeMode(option.$1),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
