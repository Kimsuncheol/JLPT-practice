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

  group('parseDialogueScript', () {
    test('strips speaker tags and keeps the utterance text', () {
      final turns = parseDialogueScript('M：こんにちは。\nF：どうも。');
      expect(turns.map((t) => t.text), ['こんにちは。', 'どうも。']);
    });

    test('assigns a lower pitch to M speakers and higher to F speakers', () {
      final turns = parseDialogueScript('M：こんにちは。\nF：どうも。');
      expect(turns[0].pitch, lessThan(1));
      expect(turns[1].pitch, greaterThan(1));
    });

    test('gives repeated same-speaker turns the same pitch', () {
      final turns = parseDialogueScript('M：一つ目。\nF：二つ目。\nM：三つ目。');
      expect(turns[0].pitch, turns[2].pitch);
    });

    test('distinguishes multiple speakers on the same side (M1/M2)', () {
      final turns = parseDialogueScript('M1：僕がやる。\nM2：うーん。\nF：だめだめ。');
      expect(turns[0].pitch, isNot(turns[1].pitch));
      expect(turns[0].pitch, lessThan(1));
      expect(turns[1].pitch, lessThan(1));
    });

    test('narrates untagged scene-setting lines at neutral pitch', () {
      final turns = parseDialogueScript('家族三人がペットについて話している\nM：犬を飼いたいんだ。');
      expect(turns[0].pitch, 1);
      expect(turns[0].text, '家族三人がペットについて話している');
    });

    test('skips blank lines and a leftover [Script] marker', () {
      final turns = parseDialogueScript('[Script]\n\nM：こんにちは。\n');
      expect(turns.length, 1);
      expect(turns.single.text, 'こんにちは。');
    });

    test('returns an empty list for an empty passage', () {
      expect(parseDialogueScript(''), isEmpty);
    });
  });
}
