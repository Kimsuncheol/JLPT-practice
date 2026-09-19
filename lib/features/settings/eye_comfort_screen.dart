import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

class EyeComfortScreen extends ConsumerWidget {
  const EyeComfortScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('eyeComfort'))),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final controller = ref.read(appControllerProvider.notifier);
          final strings = context.strings;
          final percent = '${(state.eyeComfortLevel * 100).round()}%';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.wb_twilight_rounded),
                      title: Text(strings('eyeComfort')),
                      subtitle: Text(strings('eyeComfortSubtitle')),
                      value: state.eyeComfortEnabled,
                      onChanged: controller.setEyeComfortEnabled,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Row(
                        children: [
                          Expanded(child: Text(strings('eyeComfortStrength'))),
                          Text(
                            percent,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      value: state.eyeComfortLevel,
                      label: percent,
                      divisions: 20,
                      semanticFormatterCallback: (value) =>
                          '${strings('eyeComfortStrength')} ${(value * 100).round()}%',
                      onChanged: state.eyeComfortEnabled
                          ? controller.setEyeComfortLevel
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
