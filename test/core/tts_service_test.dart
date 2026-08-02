import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';

void main() {
  group('prepareJapaneseTextForSpeech', () {
    test('removes hiragana furigana attached to kanji', () {
      expect(prepareJapaneseTextForSpeech('今日（きょう）は何（なに）をしますか？'), '今日は何をしますか？');
    });

    test('removes ASCII and spaced furigana forms', () {
      expect(
        prepareJapaneseTextForSpeech('日本語 (にほんご)を勉強（べんきょう）します。'),
        '日本語を勉強します。',
      );
    });

    test('supports readings attached to a kanji inside a word', () {
      expect(prepareJapaneseTextForSpeech('食（た）べる'), '食べる');
    });

    test('preserves explanatory and standalone parentheses', () {
      expect(
        prepareJapaneseTextForSpeech('東京（日本の首都）で（たぶん）会います。'),
        '東京（日本の首都）で（たぶん）会います。',
      );
    });
  });
}
