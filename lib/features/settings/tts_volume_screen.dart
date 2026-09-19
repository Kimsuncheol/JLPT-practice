import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';
import 'package:volume_controller/volume_controller.dart';

/// Chooses whether pronunciation follows the system volume or a level of its
/// own.
class TtsVolumeScreen extends ConsumerStatefulWidget {
  const TtsVolumeScreen({super.key});

  @override
  ConsumerState<TtsVolumeScreen> createState() => _TtsVolumeScreenState();
}

class _TtsVolumeScreenState extends ConsumerState<TtsVolumeScreen> {
  StreamSubscription<double>? _systemVolumeSubscription;
  double? _systemVolume;

  @override
  void initState() {
    super.initState();
    try {
      _systemVolumeSubscription = VolumeController.instance.addListener((
        volume,
      ) {
        if (mounted) setState(() => _systemVolume = volume);
      });
    } catch (_) {
      // The system volume is only shown for information.
    }
  }

  @override
  void dispose() {
    unawaited(_systemVolumeSubscription?.cancel());
    try {
      VolumeController.instance.removeListener();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('ttsVolume'))),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final controller = ref.read(appControllerProvider.notifier);
          final strings = context.strings;
          final colors = Theme.of(context).colorScheme;
          final useSlider = state.ttsVolumeMode == TtsVolumeMode.slider;
          final level = '${(state.ttsVolume * 100).round()}%';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                child: Text(
                  strings('ttsVolumeHint'),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: RadioGroup<TtsVolumeMode>(
                  groupValue: state.ttsVolumeMode,
                  onChanged: (mode) {
                    if (mode != null) controller.setTtsVolumeMode(mode);
                  },
                  child: Column(
                    children: [
                      RadioListTile<TtsVolumeMode>(
                        value: TtsVolumeMode.system,
                        secondary: const Icon(Icons.phone_android_rounded),
                        title: Text(strings('volumeSystem')),
                        subtitle: Text(strings('volumeSystemBody')),
                      ),
                      if (!useSlider) _systemVolumeReadout(context),
                      RadioListTile<TtsVolumeMode>(
                        value: TtsVolumeMode.slider,
                        secondary: const Icon(Icons.tune_rounded),
                        title: Text(strings('volumeSlider')),
                        subtitle: Text(strings('volumeSliderBody')),
                      ),
                      if (useSlider) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: Row(
                            children: [
                              Expanded(child: Text(strings('volumeLevel'))),
                              Text(
                                level,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ),
                        Slider(
                          value: state.ttsVolume,
                          label: level,
                          divisions: 20,
                          semanticFormatterCallback: (value) =>
                              '${strings('volumeLevel')} ${(value * 100).round()}%',
                          onChanged: controller.setTtsVolume,
                        ),
                      ],
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

  /// Read-only view of the volume the system currently has.
  Widget _systemVolumeReadout(BuildContext context) {
    final volume = _systemVolume;
    if (volume == null) return const SizedBox.shrink();
    final percent = '${(volume * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(context.strings('volumeCurrentSystem'))),
              Text(percent, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: volume.clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}
