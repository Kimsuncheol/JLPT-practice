import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

/// Settings for covering words and meanings with tape on the word study
/// screen. The study screen's bottom buttons flip the same switches.
class RecallCoverScreen extends ConsumerWidget {
  const RecallCoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('recallCover'))),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final controller = ref.read(appControllerProvider.notifier);
          final strings = context.strings;
          final colors = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                child: Text(
                  strings('recallCoverHint'),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              _Group(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.abc_rounded),
                    title: Text(strings('hideWord')),
                    subtitle: Text(strings('coverWordBody')),
                    value: state.hideWord,
                    onChanged: controller.setHideWord,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Group(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.translate_rounded),
                    title: Text(strings('hideMeanings')),
                    subtitle: Text(strings('coverMeaningsBody')),
                    value: state.hideMeanings,
                    onChanged: controller.setHideMeanings,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}
