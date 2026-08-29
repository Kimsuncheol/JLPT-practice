import 'package:audio_session/audio_session.dart';
import 'package:flutter_tts/flutter_tts.dart';

final _furiganaAfterKanji = RegExp(
  r'([\u3400-\u4DBF\u4E00-\u9FFF々〆ヵヶ])[\u0020\u3000]*(?:（[ぁ-ゖァ-ヺー・]+）|\([ぁ-ゖァ-ヺー・]+\))',
);

/// Removes kana readings attached to kanji while preserving other parentheses.
String prepareJapaneseTextForSpeech(String text) {
  return text.replaceAllMapped(_furiganaAfterKanji, (match) => match.group(1)!);
}

/// Matches a speaker-tagged dialogue line such as `M：...` or `F1：...`.
final _dialogueSpeakerLine = RegExp(r'^([A-Za-z][A-Za-z0-9]{0,2})[：:]\s*(.+)$');

/// One line of a listening-question transcript, ready to be spoken.
class DialogueTurn {
  const DialogueTurn({required this.pitch, required this.text});

  final double pitch;
  final String text;
}

/// Parses a listening-question passage (lines like `M：...` / `F：...`,
/// with occasional untagged narration lines such as a scene description)
/// into turns with a pitch assigned per speaker so a single TTS voice can
/// stand in for a multi-person conversation.
List<DialogueTurn> parseDialogueScript(String passage) {
  final pitchBySpeaker = <String, double>{};
  var nextLowPitch = 0.85;
  var nextHighPitch = 1.15;
  final turns = <DialogueTurn>[];

  for (final rawLine in passage.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line == '[Script]') continue;
    final match = _dialogueSpeakerLine.firstMatch(line);
    if (match == null) {
      // Untagged line (e.g. a scene-setting sentence) — narrate at neutral pitch.
      turns.add(DialogueTurn(pitch: 1, text: line));
      continue;
    }
    final speaker = match.group(1)!;
    final text = match.group(2)!;
    final pitch = pitchBySpeaker.putIfAbsent(speaker, () {
      if (speaker.startsWith('M') || speaker.startsWith('N')) {
        final value = nextLowPitch;
        nextLowPitch -= 0.1;
        return value;
      }
      final value = nextHighPitch;
      nextHighPitch += 0.15;
      return value;
    });
    turns.add(DialogueTurn(pitch: pitch, text: text));
  }
  return turns;
}

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
    final speechText = prepareJapaneseTextForSpeech(text).trim();
    if (speechText.isEmpty) return;

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
      await _tts.speak(speechText, focus: false);
    } finally {
      if (request == _speechRequest) {
        await _releaseAudioFocus();
      }
    }
  }

  /// Speaks a multi-turn conversation (see [parseDialogueScript]), shifting
  /// pitch per turn so a single device voice can stand in for multiple
  /// speakers. Used for listening-question transcripts, which have no
  /// bundled audio.
  Future<void> speakDialogue(List<DialogueTurn> turns) async {
    if (turns.isEmpty) return;

    final request = ++_speechRequest;
    await _ready;
    if (request != _speechRequest) return;

    await _tts.stop();
    if (request != _speechRequest) return;

    final hasAudioFocus = await _audioSession.setActive(true);
    if (!hasAudioFocus || request != _speechRequest) return;

    try {
      for (final turn in turns) {
        if (request != _speechRequest) return;
        final speechText = prepareJapaneseTextForSpeech(turn.text).trim();
        if (speechText.isEmpty) continue;
        await _tts.setPitch(turn.pitch);
        await _tts.speak(speechText, focus: false);
      }
    } finally {
      await _tts.setPitch(1);
      if (request == _speechRequest) {
        await _releaseAudioFocus();
      }
    }
  }

  Future<void> stop() async {
    _speechRequest++;
    await _ready;
    await _tts.stop();
    await _releaseAudioFocus();
  }

  Future<void> dispose() => stop();

  Future<void> _releaseAudioFocus() => _audioSession.setActive(
    false,
    avAudioSessionSetActiveOptions:
        AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
  );
}
