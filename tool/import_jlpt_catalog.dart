import 'dart:convert';
import 'dart:io';

const _repositoryBaseUrl =
    'https://raw.githubusercontent.com/tristcoil/hanabira.org/main/'
    'backend/express/json_data';
const _catalogPath = 'assets/data/jlpt_catalog.json';

Future<void> main() async {
  final destination = File(_catalogPath);
  final previousExamples = _loadPreviousExamples(destination);
  final output = <Map<String, Object?>>[];
  final client = HttpClient();

  try {
    for (var number = 1; number <= 5; number++) {
      final uri = Uri.parse(
        '$_repositoryBaseUrl/'
        'wordsTanos_openai_JLPT_N${number}_tanos_vocab_list.json',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to download N$number: HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      final records =
          (jsonDecode(await utf8.decoder.bind(response).join())
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      for (var index = 0; index < records.length; index++) {
        final source = records[index];
        final word = (source['vocabulary_original'] as String).trim();
        final suppliedReading =
            (source['vocabulary_simplified'] as String? ?? '').trim();
        final reading = suppliedReading.isEmpty ? word : suppliedReading;
        final suppliedMeaning = (source['vocabulary_english'] as String? ?? '')
            .trim();
        final meaning = suppliedMeaning.isEmpty
            ? _missingMeanings[word]
            : suppliedMeaning;
        if (word.isEmpty || reading.isEmpty || meaning == null) {
          throw FormatException('Incomplete N$number source row ${index + 1}');
        }
        output.add({
          'word': word,
          'reading': reading,
          'meaning': meaning,
          'level': 'N$number',
          'rank': index + 1,
          'example':
              previousExamples['N$number\u0000$word\u0000$reading'] ??
              previousExamples['\u0000$word\u0000$reading'],
        });
      }
      stdout.writeln('N$number: ${records.length} words');
    }
  } finally {
    client.close(force: true);
  }

  await _writeAtomically(destination, output);
  stdout.writeln('Wrote ${output.length} words to ${destination.path}');
}

Map<String, Map<String, dynamic>> _loadPreviousExamples(File file) {
  if (!file.existsSync()) return {};
  final records = (jsonDecode(file.readAsStringSync()) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final examples = <String, Map<String, dynamic>>{};
  for (final record in records) {
    final example = record['example'];
    if (example is! Map<String, dynamic> ||
        (example['sentence'] as String? ?? '').isEmpty) {
      continue;
    }
    final word = record['word'];
    final reading = record['reading'];
    examples['${record['level']}\u0000$word\u0000$reading'] = example;
    examples.putIfAbsent('\u0000$word\u0000$reading', () => example);
  }
  return examples;
}

Future<void> _writeAtomically(
  File destination,
  List<Map<String, Object?>> records,
) async {
  final temporary = File('${destination.path}.tmp');
  await temporary.writeAsString(jsonEncode(records), flush: true);
  await temporary.rename(destination.path);
}

const _missingMeanings = <String, String>{
  'あひら': 'here and there',
  'いっていらっしゃい': 'go and come back; take care',
  'いってらっしゃい': 'see you; take care',
  'いってまいります': "I'll go and come back; see you later",
  '炒る': 'to parch, to roast',
  'オーバーコート': 'overcoat',
  'おかけください': 'please sit down',
  'おきのどくに': 'I am sorry to hear that',
  'おげんきで': 'take care; stay well',
  'お出掛け': 'outing',
  '思いっ切り': 'very, much, fully',
  '関西': 'south-western half of Japan, including Osaka',
  '咥える': 'to hold something in the mouth',
  'ごぞんじですか': 'do you know?',
  'しょうがない': 'it cannot be helped',
  'ずうっと': 'all the time, all the way',
  '棄てる': 'to discard; to throw away',
  '清む': 'to clear; to become transparent',
  'ずらり': 'in a line, in a row',
  '滑れる': 'to slip; to shift out of position',
  'せっせと': 'busily, diligently',
  '先々週': 'the week before last',
  'そうっと': 'softly, cautiously, gently',
  'そのころ': 'in those days, at that time',
  'それなのに': 'nevertheless, even so',
  '存ずる': 'to know (humble)',
  '茶色い': 'brown',
  '通ずる': 'to lead, to run, to open',
  '転々': 'from one place to another',
  '傾らか': 'gradual, gentle',
  'にこにこ': 'smilingly, cheerfully',
  'バイバイ': 'bye-bye',
  '初めに': 'to begin with, first of all',
  '斜': 'diagonal',
  '×': 'cross; incorrect mark',
  'ぴたり': 'exactly; closely',
  '破く': 'to tear',
  '慶ぶ': 'to be delighted, to be glad',
  'お目に掛かる': 'to meet, to see (humble)',
  '急に': 'suddenly',
  '小': 'small',
  '税': 'tax',
  'それと': 'and; also',
  '大': 'big, great',
  'だが': 'but, however',
  '釣': 'fishing',
  'できれば': 'if possible',
  'ノー': 'no',
  'はあ': 'yes; a sigh or expression of surprise',
  '番': 'number; turn',
  '密': 'dense; close',
};
