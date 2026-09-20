import 'package:jlpt_practice/core/services/flutter_tts_engine.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';

class JapaneseTtsService extends AudioFocusTtsService {
  factory JapaneseTtsService({
    required TtsVolumePreference Function() volumePreference,
    required String Function() voiceId,
  }) {
    final engine = FlutterTtsEngine();
    return JapaneseTtsService._(
      engine: engine,
      volumePreference: volumePreference,
    );
  }

  JapaneseTtsService._({
    required FlutterTtsEngine engine,
    required TtsVolumePreference Function() volumePreference,
  }) : _engine = engine,
       super(
         audioSessionController: SystemTtsAudioSession.initialized,
         engineSelector: () => engine,
         volumePreference: volumePreference,
       );

  final FlutterTtsEngine _engine;

  Future<void> prepare() async {}
  Future<bool> get isOfflineModelInstalled async => false;
  Future<void> speakWithVoice(String text, String voiceId) => speak(text);

  @override
  Future<void> dispose() async {
    await super.dispose();
    await _engine.dispose();
  }
}
