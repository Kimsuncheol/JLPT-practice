import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';

class FlutterTtsEngine implements TtsEngine, DialogueTtsEngine {
  FlutterTtsEngine({FlutterTts? flutterTts})
    : _tts = flutterTts ?? FlutterTts() {
    _ready = _configure(_tts);
  }

  final FlutterTts _tts;
  late final Future<void> _ready;
  var _disposed = false;

  static Future<void> _configure(FlutterTts tts) async {
    await tts.awaitSpeakCompletion(true);
    await tts.setLanguage('ja-JP');
    await tts.setSpeechRate(0.42);
    await tts.setVolume(1);
    await tts.setPitch(1);
    // Do not call setIosAudioCategory: audio_session owns the app-wide iOS
    // session. focus:false below prevents flutter_tts requesting Android focus.
  }

  @override
  Future<void> speak(String text, {String lang = 'ja-JP'}) async {
    if (_disposed) return;
    await _ready;
    if (_disposed) return;
    await _tts.setLanguage(lang);
    await _tts.speak(text, focus: false);
  }

  @override
  Future<void> speakDialogue(List<DialogueTurn> turns) async {
    if (_disposed) return;
    await _ready;
    try {
      for (final turn in turns) {
        if (_disposed) return;
        final text = prepareJapaneseTextForSpeech(turn.text).trim();
        if (text.isEmpty) continue;
        await _tts.setPitch(turn.pitch);
        await _tts.speak(text, focus: false);
      }
    } finally {
      await _tts.setPitch(1);
    }
  }

  @override
  Future<void> stop() async {
    await _ready;
    await _tts.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
  }
}
