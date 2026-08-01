import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService() {
    _tts
      ..setLanguage('ja-JP')
      ..setSpeechRate(0.42)
      ..setPitch(1);
  }

  final FlutterTts _tts = FlutterTts();

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> dispose() => _tts.stop();
}
