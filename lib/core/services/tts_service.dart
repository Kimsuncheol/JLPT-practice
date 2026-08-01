import 'package:audio_session/audio_session.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService() {
    _ready = _initialize();
  }

  final FlutterTts _tts = FlutterTts();
  late final AudioSession _audioSession;
  late final Future<void> _ready;
  int _speechRequest = 0;

  Future<void> _initialize() async {
    _audioSession = await AudioSession.instance;
    await _audioSession.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.duckOthers |
            AVAudioSessionCategoryOptions.interruptSpokenAudioAndMixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.assistanceNavigationGuidance,
        ),
        // A transient focus request makes other media pause temporarily and
        // sends it AUDIOFOCUS_GAIN when focus is abandoned after speech.
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
        androidWillPauseWhenDucked: false,
      ),
    );
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('ja-JP');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1);
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    final request = ++_speechRequest;
    await _ready;
    if (request != _speechRequest) return;

    await _tts.stop();
    if (request != _speechRequest) return;

    final hasAudioFocus = await _audioSession.setActive(true);
    if (!hasAudioFocus || request != _speechRequest) return;

    try {
      // AudioSession owns focus so flutter_tts must not acquire a second,
      // independently managed focus request.
      await _tts.speak(text, focus: false);
    } finally {
      if (request == _speechRequest) {
        await _releaseAudioFocus();
      }
    }
  }

  Future<void> dispose() async {
    _speechRequest++;
    await _ready;
    await _tts.stop();
    await _releaseAudioFocus();
  }

  Future<void> _releaseAudioFocus() => _audioSession.setActive(
    false,
    avAudioSessionSetActiveOptions:
        AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
  );
}
