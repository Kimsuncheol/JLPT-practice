import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/utils/daily_lesson_readings.dart';

void main() {
  final cases = <({String japanese, String reading, Map<String, String> ruby})>[
    (
      japanese: '取引先の田中部長と会うのは、初めてですか。',
      reading:
          'とりひきさきの たなかぶちょうと あうのは、 はじめてですか。 (토리히키사키 노 타나카 부 쵸- 토 아우 노 와 하지 메 데 스 까)',
      ruby: {'取引先': 'とりひきさき', '田中部長': 'たなかぶちょう', '会': 'あ', '初': 'はじ'},
    ),
    (
      japanese: 'いえ、一度接待の席に同席したので、面識はあります。',
      reading:
          'いえ、いちど せったいの せきに どうせきしたので、めんしきは あります。 (이 에 이찌 도 셋 따 이 노 세키 니 도-세키 시 따 노 데 면 시 끼 와 아 리 마 스)',
      ruby: {'一度接待': 'いちどせったい', '席': 'せき', '同席': 'どうせき', '面識': 'めんしき'},
    ),
    (
      japanese: '本人は気付いていないようですね。',
      reading: 'ほんにん は きづ いてないよう ですね。',
      ruby: {'本人': 'ほんにん', '気付': 'きづ'},
    ),
    (
      japanese: 'A 昨日は久しぶりに旧友と会って、とりとめのない話をして楽しかったわ。',
      reading:
          'キノ- ワ ヒサシブ リ ニュ ュ- ユ  또 앗 테 토 리 토 메 ノ ナ イ 하 나 시 オ 시 て タ ノ 시 갓 따 와',
      ruby: {
        '昨日': 'きのう',
        '久': 'ひさ',
        '旧友': 'きゅうゆう',
        '会': 'あ',
        '話': 'はなし',
        '楽': 'たの',
      },
    ),
    (
      japanese: 'ああ、ちょっと上から目線で話すからですね。',
      reading: 'ああ、ちょっと うえ から めせん で はなす からですね。',
      ruby: {'上': 'うえ', '目線': 'めせん', '話': 'はな'},
    ),
  ];

  for (final item in cases) {
    test('complete furigana for screenshot sentence: ${item.japanese}', () {
      final segments = dailyLessonSegments(item.japanese, item.reading);
      expect(segments.map((s) => s.text).join(), item.japanese);
      expect({
        for (final s in segments)
          if (s.ruby != null) s.text: s.ruby,
      }, item.ruby);
      expect(
        segments
            .where((s) => RegExp(r'[一-鿿]').hasMatch(s.text))
            .every((s) => s.ruby != null),
        isTrue,
      );
      expect(
        dailyLessonReading(item.japanese, item.reading),
        isNot(contains(RegExp(r'[가-힣A-Z]'))),
      );
    });
  }

  test(
    'exact corrections cover absent readings without changing unknown sentences',
    () {
      expect(dailyLessonReading('本人は気付いていないようですね。', ''), 'ほんにんはきづいていないようですね。');
      expect(dailyLessonReading('未知の名前', ''), isEmpty);
      expect(dailyLessonReading('未知の名前', '알 수 없음'), isEmpty);
    },
  );

  test(
    'kana-only dialogue uses Japanese when source pronunciation is corrupt',
    () {
      expect(
        dailyLessonReading('B へえ、それはよかったね。', '헤 - 소 레 와 요 갓 따 네'),
        isEmpty,
      );
      expect(
        dailyLessonSpeakerPrefix.firstMatch('B へえ、それはよかったね。')?.group(1),
        'B',
      );
      expect(dailyLessonSpeakerPrefix.firstMatch('Ａ：昨日は')?.group(1), 'Ａ');
    },
  );
}
