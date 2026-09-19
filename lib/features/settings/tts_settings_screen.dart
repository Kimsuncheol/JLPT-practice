import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/japanese_tts_service.dart';

class TtsSettingsScreen extends ConsumerStatefulWidget {
  const TtsSettingsScreen({super.key});

  @override
  ConsumerState<TtsSettingsScreen> createState() => _TtsSettingsScreenState();
}

class _TtsSettingsScreenState extends ConsumerState<TtsSettingsScreen> {
  static const _previewText = 'こんにちは。今日も日本語を楽しく勉強しましょう。';
  String? _previewingVoiceId;

  Future<void> _preview(JapaneseTtsVoice voice) async {
    if (_previewingVoiceId != null) return;
    setState(() => _previewingVoiceId = voice.id);
    final service = ref.read(ttsServiceProvider);
    try {
      if (service is JapaneseTtsService) await service.prepare();
      if (!mounted) return;
      if (service is JapaneseTtsService) {
        await service.speakWithVoice(_previewText, voice.id);
      } else {
        await service.speak(_previewText);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings('ttsModelUnavailable'))),
      );
    } finally {
      if (mounted) setState(() => _previewingVoiceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('ttsSettings'))),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (settings) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              context.strings('ttsSettingsBody'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: settings.ttsVoiceId,
              onChanged: (voiceId) {
                if (voiceId != null) {
                  ref
                      .read(appControllerProvider.notifier)
                      .setTtsVoiceId(voiceId);
                }
              },
              child: Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < japaneseTtsVoices.length;
                      index++
                    ) ...[
                      _VoiceTile(
                        voice: japaneseTtsVoices[index],
                        previewing:
                            _previewingVoiceId == japaneseTtsVoices[index].id,
                        previewDisabled: _previewingVoiceId != null,
                        onPreview: () => _preview(japaneseTtsVoices[index]),
                      ),
                      if (index != japaneseTtsVoices.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.offline_bolt_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.strings('ttsOfflineModelNote'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.voice,
    required this.previewing,
    required this.previewDisabled,
    required this.onPreview,
  });

  final JapaneseTtsVoice voice;
  final bool previewing;
  final bool previewDisabled;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) => RadioListTile<String>(
    value: voice.id,
    title: Text(voice.name),
    subtitle: Text(context.strings(voice.descriptionKey)),
    secondary: previewing
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : IconButton(
            tooltip: context.strings('previewVoice'),
            onPressed: previewDisabled ? null : onPreview,
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
  );
}
