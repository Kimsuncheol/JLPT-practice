import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';
import 'package:volume_controller/volume_controller.dart';

final _furiganaAfterKanji = RegExp(
  r'([\u3400-\u4DBF\u4E00-\u9FFF々〆ヵヶ])[\u0020\u3000]*(?:（[ぁ-ゖァ-ヺー・]+）|\([ぁ-ゖァ-ヺー・]+\))',
);

String prepareJapaneseTextForSpeech(String text) =>
    text.replaceAllMapped(_furiganaAfterKanji, (match) => match.group(1)!);

List<String> splitReadings(String reading) => reading
    .split(RegExp(r'[/／]'))
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();

final _dialogueSpeakerLine = RegExp(r'^([A-Za-z][A-Za-z0-9]{0,2})[：:]\s*(.+)$');

class DialogueTurn {
  const DialogueTurn({required this.pitch, required this.text});
  final double pitch;
  final String text;
}

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
      turns.add(DialogueTurn(pitch: 1, text: line));
      continue;
    }
    final speaker = match.group(1)!;
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
    turns.add(DialogueTurn(pitch: pitch, text: match.group(2)!));
  }
  return turns;
}

class TtsVolumePreference {
  const TtsVolumePreference({required this.mode, required this.level});
  static const system = TtsVolumePreference(
    mode: TtsVolumeMode.system,
    level: 1,
  );
  final TtsVolumeMode mode;
  final double level;
}

/// Playback engine contract. [speak] completes on completion, cancellation,
/// or failure, never merely when playback starts.
abstract interface class TtsEngine {
  Future<void> speak(String text, {String lang = 'ja-JP'});
  Future<void> stop();
  Future<void> dispose();
}

abstract interface class DialogueTtsEngine {
  Future<void> speakDialogue(List<DialogueTurn> turns);
}

/// A synthesizing engine can ask for focus only once audio is ready.
abstract interface class DeferredFocusTtsEngine implements TtsEngine {
  Future<void> speakWithPlaybackGate(
    String text, {
    String lang = 'ja-JP',
    required Future<bool> Function() beforePlayback,
  });
}

abstract interface class DeferredFocusDialogueTtsEngine
    implements DialogueTtsEngine {
  Future<void> speakDialogueWithPlaybackGate(
    List<DialogueTurn> turns, {
    required Future<bool> Function() beforePlayback,
  });
}

abstract interface class TtsAudioSession {
  Stream<AudioInterruptionEvent> get interruptionEventStream;
  Stream<void> get becomingNoisyEventStream;
  Future<bool> setActive(bool active);
  Future<bool> deactivateAndNotifyOthers();
}

class SystemTtsAudioSession implements TtsAudioSession {
  SystemTtsAudioSession._(this._session);
  final AudioSession _session;

  static AndroidAudioFocusGainType androidFocusGainType =
      AndroidAudioFocusGainType.gainTransient;
  static bool duckOthersOnIos = false;
  static SystemTtsAudioSession? _initialized;

  static SystemTtsAudioSession get initialized =>
      _initialized ??
      (throw StateError('TTS audio session was not initialized at app start.'));

  static Future<SystemTtsAudioSession> create() async {
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: duckOthersOnIos
            ? AVAudioSessionCategoryOptions.duckOthers
            : AVAudioSessionCategoryOptions
                  .interruptSpokenAudioAndMixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.assistanceNavigationGuidance,
        ),
        androidAudioFocusGainType: androidFocusGainType,
        androidWillPauseWhenDucked: true,
      ),
    );
    return _initialized ??= SystemTtsAudioSession._(session);
  }

  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      _session.interruptionEventStream;
  @override
  Stream<void> get becomingNoisyEventStream =>
      _session.becomingNoisyEventStream;
  @override
  Future<bool> setActive(bool active) => _session.setActive(active);
  @override
  Future<bool> deactivateAndNotifyOthers() => _session.setActive(
    false,
    avAudioSessionSetActiveOptions:
        AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
  );
}

/// Stable interface consumed by UI and test fakes.
abstract interface class TtsService {
  Future<void> speak(String text);
  Future<void> speakDialogue(List<DialogueTurn> turns);
  Future<void> stop();
  Future<void> dispose();
}

/// Selects the engine and is the sole owner of audio focus and volume changes.
class AudioFocusTtsService with WidgetsBindingObserver implements TtsService {
  AudioFocusTtsService({
    required this.audioSessionController,
    required this.engineSelector,
    TtsVolumePreference Function()? volumePreference,
  }) : _volumePreference =
           volumePreference ?? (() => TtsVolumePreference.system) {
    WidgetsBinding.instance.addObserver(this);
    _interruptionSubscription = audioSessionController.interruptionEventStream
        .listen((event) {
          if (event.begin) unawaited(stop());
        });
    _noisySubscription = audioSessionController.becomingNoisyEventStream.listen(
      (_) => unawaited(stop()),
    );
  }

  final TtsAudioSession audioSessionController;
  final TtsEngine Function() engineSelector;
  final TtsVolumePreference Function() _volumePreference;
  late final StreamSubscription<AudioInterruptionEvent>
  _interruptionSubscription;
  late final StreamSubscription<void> _noisySubscription;
  TtsEngine? _activeEngine;
  double? _systemVolumeToRestore;
  var _requestId = 0;
  var _focusHeld = false;
  var _disposed = false;

  @override
  Future<void> speak(String text) async {
    final speechText = prepareJapaneseTextForSpeech(text).trim();
    if (speechText.isEmpty || _disposed) return;
    final request = ++_requestId;
    final previous = _activeEngine;
    final selected = engineSelector();
    _activeEngine = selected;
    await previous?.stop();
    if (request != _requestId || _disposed) return;
    try {
      if (selected is DeferredFocusTtsEngine) {
        await selected.speakWithPlaybackGate(
          speechText,
          lang: 'ja-JP',
          beforePlayback: () => _acquireFocus(request),
        );
      } else {
        if (!await _acquireFocus(request)) return;
        await selected.speak(speechText);
      }
    } finally {
      if (request == _requestId) {
        _activeEngine = null;
        await _releaseFocus();
      }
    }
  }

  @override
  Future<void> speakDialogue(List<DialogueTurn> turns) async {
    if (turns.isEmpty || _disposed) return;
    final request = ++_requestId;
    final previous = _activeEngine;
    final selected = engineSelector();
    _activeEngine = selected;
    await previous?.stop();
    if (request != _requestId || _disposed) return;
    try {
      if (selected is DeferredFocusDialogueTtsEngine) {
        await (selected as DeferredFocusDialogueTtsEngine)
            .speakDialogueWithPlaybackGate(
              turns,
              beforePlayback: () => _acquireFocus(request),
            );
      } else if (selected is DialogueTtsEngine) {
        if (!await _acquireFocus(request)) return;
        await (selected as DialogueTtsEngine).speakDialogue(turns);
      } else {
        if (!await _acquireFocus(request)) return;
        for (final turn in turns) {
          if (request != _requestId) return;
          await selected.speak(turn.text);
        }
      }
    } finally {
      if (request == _requestId) {
        _activeEngine = null;
        await _releaseFocus();
      }
    }
  }

  Future<bool> _acquireFocus(int request) async {
    if (request != _requestId || _disposed) return false;
    if (!_focusHeld) {
      if (!await audioSessionController.setActive(true)) return false;
      if (request != _requestId || _disposed) {
        await audioSessionController.deactivateAndNotifyOthers();
        return false;
      }
      _focusHeld = true;
      await _applyVolumePreference();
    }
    return true;
  }

  @override
  Future<void> stop() async {
    ++_requestId;
    final engine = _activeEngine;
    _activeEngine = null;
    await engine?.stop();
    await _releaseFocus();
  }

  Future<void> switchEngine() => stop();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(stop());
  }

  Future<void> _applyVolumePreference() async {
    final preference = _volumePreference();
    if (preference.mode != TtsVolumeMode.slider) return;
    try {
      final controller = VolumeController.instance..showSystemUI = false;
      _systemVolumeToRestore ??= await controller.getVolume();
      await controller.setVolume(preference.level.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> _releaseFocus() async {
    final previousVolume = _systemVolumeToRestore;
    _systemVolumeToRestore = null;
    if (previousVolume != null) {
      try {
        await (VolumeController.instance..showSystemUI = false).setVolume(
          previousVolume,
        );
      } catch (_) {}
    }
    if (_focusHeld) {
      _focusHeld = false;
      await audioSessionController.deactivateAndNotifyOthers();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    await _interruptionSubscription.cancel();
    await _noisySubscription.cancel();
    await stop();
  }
}
