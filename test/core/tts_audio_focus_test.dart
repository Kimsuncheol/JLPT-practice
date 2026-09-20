import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';

class _FakeSession implements TtsAudioSession {
  final events = <String>[];
  bool grantFocus = true;

  @override
  Stream<void> get becomingNoisyEventStream => const Stream.empty();
  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      const Stream.empty();

  @override
  Future<bool> setActive(bool active) async {
    events.add(active ? 'focus' : 'inactive');
    return grantFocus;
  }

  @override
  Future<bool> deactivateAndNotifyOthers() async {
    events.add('release');
    return true;
  }
}

class _FakeEngine implements TtsEngine {
  _FakeEngine(this.events, {this.error});
  final List<String> events;
  final Object? error;
  Completer<void>? playing;

  @override
  Future<void> speak(String text, {String lang = 'ja-JP'}) async {
    events.add('speak:$text');
    if (error != null) throw error!;
    final completion = playing;
    if (completion != null) await completion.future;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    if (!(playing?.isCompleted ?? true)) playing!.complete();
  }

  @override
  Future<void> dispose() async {}
}

class _FakeSherpaEngine implements DeferredFocusTtsEngine {
  final generated = <Completer<void>>[];
  final played = <String>[];
  var _request = 0;

  @override
  Future<void> speak(String text, {String lang = 'ja-JP'}) =>
      speakWithPlaybackGate(text, beforePlayback: () async => true);

  @override
  Future<void> speakWithPlaybackGate(
    String text, {
    String lang = 'ja-JP',
    required Future<bool> Function() beforePlayback,
  }) async {
    final request = ++_request;
    final generation = Completer<void>();
    generated.add(generation);
    await generation.future;
    if (request != _request) return;
    if (await beforePlayback()) played.add(text);
  }

  @override
  Future<void> stop() async => _request++;
  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('requests focus before speech and releases after completion', () async {
    final session = _FakeSession();
    final engine = _FakeEngine(session.events);
    final service = AudioFocusTtsService(
      audioSessionController: session,
      engineSelector: () => engine,
    );
    await service.speak('日本語');
    expect(session.events, ['focus', 'speak:日本語', 'release']);
    await service.dispose();
  });

  test('releases focus when the engine fails', () async {
    final session = _FakeSession();
    final engine = _FakeEngine(session.events, error: StateError('failure'));
    final service = AudioFocusTtsService(
      audioSessionController: session,
      engineSelector: () => engine,
    );
    await expectLater(service.speak('失敗'), throwsStateError);
    expect(session.events.last, 'release');
    await service.dispose();
  });

  test('stop cancels playback and releases focus', () async {
    final session = _FakeSession();
    final engine = _FakeEngine(session.events)..playing = Completer<void>();
    final service = AudioFocusTtsService(
      audioSessionController: session,
      engineSelector: () => engine,
    );
    final speech = service.speak('長い');
    await Future<void>.delayed(Duration.zero);
    await service.stop();
    await speech;
    expect(session.events, containsAllInOrder(['focus', 'stop', 'release']));
    await service.dispose();
  });

  test('rapid taps hold focus across handover and release once', () async {
    final session = _FakeSession();
    final first = _FakeEngine(session.events)..playing = Completer<void>();
    final second = _FakeEngine(session.events);
    var selection = 0;
    final service = AudioFocusTtsService(
      audioSessionController: session,
      engineSelector: () => selection++ == 0 ? first : second,
    );
    final oldSpeech = service.speak('first');
    await Future<void>.delayed(Duration.zero);
    await service.speak('second');
    await oldSpeech;
    expect(session.events.where((event) => event == 'focus'), hasLength(1));
    expect(session.events.where((event) => event == 'release'), hasLength(1));
    expect(
      session.events,
      containsAllInOrder(['speak:first', 'stop', 'speak:second']),
    );
    await service.dispose();
  });

  test('stale Sherpa generation is discarded and never played', () async {
    final session = _FakeSession();
    final engine = _FakeSherpaEngine();
    final service = AudioFocusTtsService(
      audioSessionController: session,
      engineSelector: () => engine,
    );
    final first = service.speak('first');
    await Future<void>.delayed(Duration.zero);
    final second = service.speak('second');
    await Future<void>.delayed(Duration.zero);
    engine.generated.first.complete();
    engine.generated.last.complete();
    await Future.wait([first, second]);
    expect(engine.played, ['second']);
    await service.dispose();
  });

  test('switching engines stops the old engine before the new one', () async {
    final session = _FakeSession();
    final first = _FakeEngine(session.events)..playing = Completer<void>();
    final second = _FakeEngine(session.events);
    var useSecond = false;
    final service = AudioFocusTtsService(
      audioSessionController: session,
      engineSelector: () => useSecond ? second : first,
    );
    final oldSpeech = service.speak('old');
    await Future<void>.delayed(Duration.zero);
    useSecond = true;
    await service.speak('new');
    await oldSpeech;
    expect(
      session.events,
      containsAllInOrder(['speak:old', 'stop', 'speak:new']),
    );
    await service.dispose();
  });
}
