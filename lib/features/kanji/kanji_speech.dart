import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/features/vocabulary/audible_speech.dart';

/// Text-to-speech for a kanji study screen: speaks one reading or sentence at
/// a time and can be stopped from anywhere.
mixin KanjiSpeech<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  TtsService? _ttsService;

  /// Bumped whenever speech is stopped, so a tap still waiting on the volume
  /// check cannot start speaking after the learner has moved on.
  int _speechRequest = 0;

  /// Speaks [speech] after warning about a muted or quiet device.
  Future<void> speakTapped(String speech) async {
    final request = ++_speechRequest;
    final settings = ref.read(appControllerProvider).value;
    if (!await confirmSpeechAudible(context, settings)) return;
    if (!mounted || request != _speechRequest) return;
    speak(speech);
  }

  /// Speaks [speech] alone: a bare reading or one example sentence.
  void speak(String speech) {
    _ttsService ??= ref.read(ttsServiceProvider);
    unawaited(_ttsService!.speak(speech));
  }

  void stopSpeech() {
    _speechRequest++;
    final service = _ttsService;
    if (service != null) unawaited(service.stop());
  }
}
