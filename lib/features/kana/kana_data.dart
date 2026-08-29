enum KanaScript { hiragana, katakana }

class KanaCharacter {
  const KanaCharacter({required this.character, required this.romaji});

  final String character;
  final String romaji;
}

/// A phonetically-related cluster of kana (e.g. "vowels", "yōon"),
/// rendered as its own labeled section in the kana chart.
class KanaGroup {
  const KanaGroup({required this.titleKey, required this.items, this.noteKey});

  final String titleKey;
  final List<KanaCharacter> items;
  final String? noteKey;
}

class KanaCatalog {
  KanaCatalog._();

  static const _vowelsHira = ['あ', 'い', 'う', 'え', 'お'];
  static const _vowelsKata = ['ア', 'イ', 'ウ', 'エ', 'オ'];
  static const _vowelsRomaji = ['a', 'i', 'u', 'e', 'o'];

  static const _consonantRowsHira = [
    ['か', 'き', 'く', 'け', 'こ'],
    ['さ', 'し', 'す', 'せ', 'そ'],
    ['た', 'ち', 'つ', 'て', 'と'],
    ['な', 'に', 'ぬ', 'ね', 'の'],
    ['は', 'ひ', 'ふ', 'へ', 'ほ'],
    ['ま', 'み', 'む', 'め', 'も'],
    ['ら', 'り', 'る', 'れ', 'ろ'],
  ];
  static const _consonantRowsKata = [
    ['カ', 'キ', 'ク', 'ケ', 'コ'],
    ['サ', 'シ', 'ス', 'セ', 'ソ'],
    ['タ', 'チ', 'ツ', 'テ', 'ト'],
    ['ナ', 'ニ', 'ヌ', 'ネ', 'ノ'],
    ['ハ', 'ヒ', 'フ', 'ヘ', 'ホ'],
    ['マ', 'ミ', 'ム', 'メ', 'モ'],
    ['ラ', 'リ', 'ル', 'レ', 'ロ'],
  ];
  static const _consonantRowsRomaji = [
    ['ka', 'ki', 'ku', 'ke', 'ko'],
    ['sa', 'shi', 'su', 'se', 'so'],
    ['ta', 'chi', 'tsu', 'te', 'to'],
    ['na', 'ni', 'nu', 'ne', 'no'],
    ['ha', 'hi', 'fu', 'he', 'ho'],
    ['ma', 'mi', 'mu', 'me', 'mo'],
    ['ra', 'ri', 'ru', 're', 'ro'],
  ];

  static const _glidesHira = ['や', 'ゆ', 'よ', 'わ', 'を'];
  static const _glidesKata = ['ヤ', 'ユ', 'ヨ', 'ワ', 'ヲ'];
  static const _glidesRomaji = ['ya', 'yu', 'yo', 'wa', 'wo'];

  static const _voicedRowsHira = [
    ['が', 'ぎ', 'ぐ', 'げ', 'ご'],
    ['ざ', 'じ', 'ず', 'ぜ', 'ぞ'],
    ['だ', 'ぢ', 'づ', 'で', 'ど'],
    ['ば', 'び', 'ぶ', 'べ', 'ぼ'],
  ];
  static const _voicedRowsKata = [
    ['ガ', 'ギ', 'グ', 'ゲ', 'ゴ'],
    ['ザ', 'ジ', 'ズ', 'ゼ', 'ゾ'],
    ['ダ', 'ヂ', 'ヅ', 'デ', 'ド'],
    ['バ', 'ビ', 'ブ', 'ベ', 'ボ'],
  ];
  static const _voicedRowsRomaji = [
    ['ga', 'gi', 'gu', 'ge', 'go'],
    ['za', 'ji', 'zu', 'ze', 'zo'],
    ['da', 'ji', 'zu', 'de', 'do'],
    ['ba', 'bi', 'bu', 'be', 'bo'],
  ];

  static const _semiVoicedHira = ['ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ'];
  static const _semiVoicedKata = ['パ', 'ピ', 'プ', 'ペ', 'ポ'];
  static const _semiVoicedRomaji = ['pa', 'pi', 'pu', 'pe', 'po'];

  static const _yoonRowsHira = [
    ['きゃ', 'きゅ', 'きょ'],
    ['しゃ', 'しゅ', 'しょ'],
    ['ちゃ', 'ちゅ', 'ちょ'],
    ['にゃ', 'にゅ', 'にょ'],
    ['ひゃ', 'ひゅ', 'ひょ'],
    ['みゃ', 'みゅ', 'みょ'],
    ['りゃ', 'りゅ', 'りょ'],
    ['ぎゃ', 'ぎゅ', 'ぎょ'],
    ['じゃ', 'じゅ', 'じょ'],
    ['びゃ', 'びゅ', 'びょ'],
    ['ぴゃ', 'ぴゅ', 'ぴょ'],
  ];
  static const _yoonRowsKata = [
    ['キャ', 'キュ', 'キョ'],
    ['シャ', 'シュ', 'ショ'],
    ['チャ', 'チュ', 'チョ'],
    ['ニャ', 'ニュ', 'ニョ'],
    ['ヒャ', 'ヒュ', 'ヒョ'],
    ['ミャ', 'ミュ', 'ミョ'],
    ['リャ', 'リュ', 'リョ'],
    ['ギャ', 'ギュ', 'ギョ'],
    ['ジャ', 'ジュ', 'ジョ'],
    ['ビャ', 'ビュ', 'ビョ'],
    ['ピャ', 'ピュ', 'ピョ'],
  ];
  static const _yoonRowsRomaji = [
    ['kya', 'kyu', 'kyo'],
    ['sha', 'shu', 'sho'],
    ['cha', 'chu', 'cho'],
    ['nya', 'nyu', 'nyo'],
    ['hya', 'hyu', 'hyo'],
    ['mya', 'myu', 'myo'],
    ['rya', 'ryu', 'ryo'],
    ['gya', 'gyu', 'gyo'],
    ['ja', 'ju', 'jo'],
    ['bya', 'byu', 'byo'],
    ['pya', 'pyu', 'pyo'],
  ];

  static const _moraicNasalHira = 'ん';
  static const _moraicNasalKata = 'ン';
  static const _sokuonHira = 'っ';
  static const _sokuonKata = 'ッ';
  static const _choonpu = 'ー';

  static List<KanaCharacter> _zip(List<String> chars, List<String> romaji) =>
      List.generate(
        chars.length,
        (i) => KanaCharacter(character: chars[i], romaji: romaji[i]),
        growable: false,
      );

  static List<KanaCharacter> _zipRows(
    List<List<String>> rows,
    List<List<String>> romajiRows,
  ) {
    final result = <KanaCharacter>[];
    for (var i = 0; i < rows.length; i++) {
      result.addAll(_zip(rows[i], romajiRows[i]));
    }
    return result;
  }

  /// The 46 basic (gojūon) kana for [script], used for a flat overview.
  static List<KanaCharacter> forScript(KanaScript script) {
    final isHira = script == KanaScript.hiragana;
    return [
      ..._zip(isHira ? _vowelsHira : _vowelsKata, _vowelsRomaji),
      ..._zipRows(
        isHira ? _consonantRowsHira : _consonantRowsKata,
        _consonantRowsRomaji,
      ),
      ..._zip(isHira ? _glidesHira : _glidesKata, _glidesRomaji),
      KanaCharacter(
        character: isHira ? _moraicNasalHira : _moraicNasalKata,
        romaji: 'n',
      ),
    ];
  }

  /// All kana for [script], organized into phonetic groups: vowels,
  /// consonants, semivowels/glides, voiced/semi-voiced, yōon (CyV), and
  /// special moraic elements (ん, っ, ー).
  static List<KanaGroup> groups(KanaScript script) {
    final isHira = script == KanaScript.hiragana;
    return [
      KanaGroup(
        titleKey: 'kanaGroupVowels',
        items: _zip(isHira ? _vowelsHira : _vowelsKata, _vowelsRomaji),
      ),
      KanaGroup(
        titleKey: 'kanaGroupConsonants',
        items: _zipRows(
          isHira ? _consonantRowsHira : _consonantRowsKata,
          _consonantRowsRomaji,
        ),
      ),
      KanaGroup(
        titleKey: 'kanaGroupGlides',
        items: _zip(isHira ? _glidesHira : _glidesKata, _glidesRomaji),
      ),
      KanaGroup(
        titleKey: 'kanaGroupVoiced',
        items: [
          ..._zipRows(
            isHira ? _voicedRowsHira : _voicedRowsKata,
            _voicedRowsRomaji,
          ),
          ..._zip(
            isHira ? _semiVoicedHira : _semiVoicedKata,
            _semiVoicedRomaji,
          ),
        ],
      ),
      KanaGroup(
        titleKey: 'kanaGroupYoon',
        items: _zipRows(
          isHira ? _yoonRowsHira : _yoonRowsKata,
          _yoonRowsRomaji,
        ),
      ),
      KanaGroup(
        titleKey: 'kanaGroupSpecial',
        noteKey: 'kanaGroupSpecialNote',
        items: [
          KanaCharacter(
            character: isHira ? _moraicNasalHira : _moraicNasalKata,
            romaji: 'n',
          ),
          KanaCharacter(
            character: isHira ? _sokuonHira : _sokuonKata,
            romaji: 'sokuon',
          ),
          const KanaCharacter(character: _choonpu, romaji: 'chōon'),
        ],
      ),
    ];
  }
}
