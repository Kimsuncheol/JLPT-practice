import 'package:jlpt_practice/core/services/tts_service.dart';

/// Web fallback. Native platforms use the sherpa-onnx implementation selected
/// by the conditional export in `japanese_tts_service.dart`.
class JapaneseTtsService implements TtsService {
  JapaneseTtsService({
    required TtsVolumePreference Function() volumePreference,
    required String Function() voiceId,
  }) : _fallback = TtsService(volumePreference: volumePreference);

  final TtsService _fallback;

  Future<void> prepare() async {}

  Future<bool> get isOfflineModelInstalled async => false;

  Future<void> speakWithVoice(String text, String voiceId) =>
      _fallback.speak(text);

  @override
  Future<void> speak(String text) => _fallback.speak(text);

  @override
  Future<void> speakDialogue(List<DialogueTurn> turns) =>
      _fallback.speakDialogue(turns);

  @override
  Future<void> stop() => _fallback.stop();

  @override
  Future<void> dispose() => _fallback.dispose();
}
