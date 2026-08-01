enum KanaScript { hiragana, katakana }

class KanaCharacter {
  const KanaCharacter({required this.character, required this.romaji});

  final String character;
  final String romaji;
}

class KanaCatalog {
  KanaCatalog._();

  static const _hiragana = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん';
  static const _katakana = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン';
  static const _romaji = <String>[
    'a',
    'i',
    'u',
    'e',
    'o',
    'ka',
    'ki',
    'ku',
    'ke',
    'ko',
    'sa',
    'shi',
    'su',
    'se',
    'so',
    'ta',
    'chi',
    'tsu',
    'te',
    'to',
    'na',
    'ni',
    'nu',
    'ne',
    'no',
    'ha',
    'hi',
    'fu',
    'he',
    'ho',
    'ma',
    'mi',
    'mu',
    'me',
    'mo',
    'ya',
    'yu',
    'yo',
    'ra',
    'ri',
    'ru',
    're',
    'ro',
    'wa',
    'wo',
    'n',
  ];

  static List<KanaCharacter> forScript(KanaScript script) {
    final characters = (script == KanaScript.hiragana ? _hiragana : _katakana)
        .runes
        .map(String.fromCharCode)
        .toList(growable: false);
    return List.generate(
      characters.length,
      (index) =>
          KanaCharacter(character: characters[index], romaji: _romaji[index]),
      growable: false,
    );
  }
}
