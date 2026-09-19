import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';

class LearningSettingsScreen extends ConsumerWidget {
  const LearningSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('learningSettings'))),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final controller = ref.read(appControllerProvider.notifier);
          final strings = context.strings;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _Group(
                children: [
                  ListTile(
                    leading: const Icon(Icons.menu_book_rounded),
                    title: Text(strings('learningLanguage')),
                    subtitle: Text(switch (state.meaningLanguageMode) {
                      'en' => 'English',
                      'ko' => '한국어',
                      _ => strings('system'),
                    }),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/learning-language'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Group(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.subtitles_rounded),
                    title: Text(strings('showFurigana')),
                    value: state.showFurigana,
                    onChanged: controller.setShowFurigana,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up_rounded),
                    title: Text(strings('autoAudio')),
                    value: state.autoPlayAudio,
                    onChanged: controller.setAutoPlayAudio,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Group(
                children: [
                  ListTile(
                    leading: const Icon(Icons.layers_clear_rounded),
                    title: Text(strings('recallCover')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/recall-cover'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.graphic_eq_rounded),
                    title: Text(strings('ttsVolume')),
                    subtitle: Text(
                      state.ttsVolumeMode == TtsVolumeMode.slider
                          ? '${strings('volumeSlider')} · ${(state.ttsVolume * 100).round()}%'
                          : strings('volumeSystem'),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/tts-volume'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.wb_twilight_rounded),
                    title: Text(strings('eyeComfort')),
                    subtitle: Text(
                      strings(state.eyeComfortEnabled ? 'on' : 'off'),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/eye-comfort'),
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
