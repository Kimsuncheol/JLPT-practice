import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            itemCount: descriptions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = descriptions.entries.elementAt(index);
              final selected = state.selectedLevel == entry.key;
              return Material(
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                child: ListTile(
                  minTileHeight: 76,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  title: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(entry.value),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded)
                      : null,
                  onTap: () => ref
                      .read(appControllerProvider.notifier)
                      .setLevel(entry.key),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
