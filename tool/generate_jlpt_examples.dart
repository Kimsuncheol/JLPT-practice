import 'dart:convert';
import 'dart:io';

const _catalogPath = 'assets/data/jlpt_catalog.json';
const _enrichedPath = 'assets/data/vocabulary.json';
const _endpoint = 'https://api.openai.com/v1/responses';

Future<void> main(List<String> arguments) async {
  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('OPENAI_API_KEY is required.');
    exitCode = 64;
    return;
  }

  final model = _option(arguments, '--model') ?? 'gpt-5-mini';
  final batchSize = int.parse(_option(arguments, '--batch-size') ?? '20');
  final concurrency = int.parse(_option(arguments, '--concurrency') ?? '1');
  final limit = int.tryParse(_option(arguments, '--limit') ?? '');
  final catalogFile = File(_catalogPath);
  final catalog = (jsonDecode(await catalogFile.readAsString()) as List)
      .cast<Map<String, dynamic>>();
  _importHandAuthoredExamples(catalog);

  final allMissing = catalog
      .where((entry) => !_hasCompleteExample(entry))
      .toList(growable: false);
  final missing = allMissing.take(limit ?? allMissing.length).toList();
  stdout.writeln(
    '${catalog.length - allMissing.length}/${catalog.length} already complete; '
    'generating ${missing.length} with $model.',
  );

  final client = HttpClient();
  try {
    final groupSize = batchSize * concurrency;
    for (var offset = 0; offset < missing.length; offset += groupSize) {
      final groupEnd = (offset + groupSize).clamp(0, missing.length);
      final batches = <List<Map<String, dynamic>>>[];
      for (var start = offset; start < groupEnd; start += batchSize) {
        final end = (start + batchSize).clamp(0, groupEnd);
        batches.add(missing.sublist(start, end));
      }
      final generated = await Future.wait(
        batches.map((batch) => _generateBatch(client, apiKey, model, batch)),
      );
      for (var index = 0; index < batches.length; index++) {
        for (final entry in batches[index]) {
          final key = _key(entry);
          entry['example'] = generated[index][key];
        }
      }
      await _writeAtomically(catalogFile, catalog);
      stdout.writeln(
        'Completed $groupEnd/${missing.length} (${_key(missing[groupEnd - 1])}).',
      );
    }
  } finally {
    client.close(force: true);
  }

  if (limit == null) {
    _validateComplete(catalog);
    stdout.writeln('Validated ${catalog.length} complete examples.');
  }
}

void _importHandAuthoredExamples(List<Map<String, dynamic>> catalog) {
  final file = File(_enrichedPath);
  if (!file.existsSync()) return;
  final enriched = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final examples = <String, Map<String, dynamic>>{
    for (final entry in enriched)
      '${entry['word']}\u0000${entry['reading']}':
          entry['example'] as Map<String, dynamic>,
  };
  for (final entry in catalog) {
    entry['example'] ??= examples['${entry['word']}\u0000${entry['reading']}'];
  }
}

Future<Map<String, Map<String, dynamic>>> _generateBatch(
  HttpClient client,
  String apiKey,
  String model,
  List<Map<String, dynamic>> batch,
) async {
  Object? lastError;
  for (var attempt = 1; attempt <= 5; attempt++) {
    try {
      final request = await client.postUrl(Uri.parse(_endpoint));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
        ..contentType = ContentType.json;
      request.write(
        jsonEncode({
          'model': model,
          'instructions': _instructions,
          'input': jsonEncode(
            batch
                .map(
                  (entry) => {
                    'key': _key(entry),
                    'word': entry['word'],
                    'reading': entry['reading'],
                    'meaning': entry['meaning'],
                    'level': entry['level'],
                  },
                )
                .toList(),
          ),
          'text': {
            'format': {
              'type': 'json_schema',
              'name': 'jlpt_examples',
              'strict': true,
              'schema': _schema,
            },
          },
        }),
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}: $body');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final text = _outputText(decoded);
      return _validateBatch(jsonDecode(text) as Map<String, dynamic>, batch);
    } catch (error) {
      lastError = error;
      if (attempt == 5) break;
      stderr.writeln('Batch failed (attempt $attempt/5): $error');
      await Future<void>.delayed(Duration(seconds: attempt * 2));
    }
  }
  throw StateError('Batch failed after 5 attempts: $lastError');
}

Map<String, Map<String, dynamic>> _validateBatch(
  Map<String, dynamic> payload,
  List<Map<String, dynamic>> batch,
) {
  final items = (payload['examples'] as List).cast<Map<String, dynamic>>();
  final byKey = <String, Map<String, dynamic>>{};
  final requestedByKey = {for (final entry in batch) _key(entry): entry};
  for (final item in items) {
    final key = item.remove('key') as String;
    if (byKey.containsKey(key)) throw FormatException('Duplicate key: $key');
    final requested = requestedByKey[key];
    if (requested == null) throw FormatException('Unexpected key: $key');
    final sentence = item['sentence'] as String;
    var answer = item['answer'] as String;
    final targetWord = requested['word'] as String;
    final targetReading = requested['reading'] as String;
    if (!sentence.contains(answer) && sentence.contains(targetWord)) {
      answer = targetWord;
      item['answer'] = answer;
    }
    if (!sentence.contains(answer) && sentence.contains(targetReading)) {
      answer = targetReading;
      item['answer'] = answer;
    }
    final canUseStem =
        targetWord.runes.length >= 3 ||
        RegExp(r'[\u3400-\u9fff々〆ヵヶ]').hasMatch(targetWord[0]);
    if (!sentence.contains(answer) && canUseStem) {
      final stem = targetWord.substring(0, targetWord.length - 1);
      if (sentence.contains(stem)) {
        answer = stem;
        item['answer'] = answer;
      }
    }
    if (answer.isEmpty || !sentence.contains(answer)) {
      throw FormatException('$key answer is not present in its sentence');
    }
    final reading = item['reading'] as String;
    final translations = item['translations'] as Map<String, dynamic>;
    if (sentence.isEmpty ||
        reading.isEmpty ||
        (translations['en'] as String).isEmpty ||
        (translations['ko'] as String).isEmpty) {
      throw FormatException('$key contains an empty example field');
    }
    item['quizSentence'] = sentence.replaceFirst(answer, '＿＿＿');
    byKey[key] = item;
  }
  final expected = batch.map(_key).toSet();
  if (byKey.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(byKey.keys.toSet()).isNotEmpty) {
    throw FormatException('Batch keys do not exactly match the request');
  }
  return byKey;
}

bool _hasCompleteExample(Map<String, dynamic> entry) {
  final example = entry['example'];
  if (example is! Map<String, dynamic>) return false;
  final translations = example['translations'];
  return [
        'sentence',
        'reading',
        'quizSentence',
        'answer',
      ].every((key) => (example[key] as String? ?? '').isNotEmpty) &&
      translations is Map<String, dynamic> &&
      (translations['en'] as String? ?? '').isNotEmpty &&
      (translations['ko'] as String? ?? '').isNotEmpty;
}

void _validateComplete(List<Map<String, dynamic>> catalog) {
  final seen = <String>{};
  for (final entry in catalog) {
    final key = _key(entry);
    if (!seen.add(key)) throw StateError('Duplicate catalog key: $key');
    if (!_hasCompleteExample(entry)) throw StateError('Incomplete: $key');
    final example = entry['example'] as Map<String, dynamic>;
    final sentence = example['sentence'] as String;
    final answer = example['answer'] as String;
    if (!sentence.contains(answer) ||
        example['quizSentence'] != sentence.replaceFirst(answer, '＿＿＿')) {
      throw StateError('Invalid quiz data: $key');
    }
  }
}

Future<void> _writeAtomically(
  File destination,
  List<Map<String, dynamic>> catalog,
) async {
  final temporary = File('${destination.path}.tmp');
  await temporary.writeAsString(jsonEncode(catalog), flush: true);
  await temporary.rename(destination.path);
}

String _outputText(Map<String, dynamic> response) {
  for (final output in (response['output'] as List? ?? const [])) {
    if (output is! Map<String, dynamic>) continue;
    for (final content in (output['content'] as List? ?? const [])) {
      if (content is Map<String, dynamic> && content['type'] == 'output_text') {
        return content['text'] as String;
      }
    }
  }
  throw FormatException('The API response contained no output_text');
}

String _key(Map<String, dynamic> entry) => '${entry['level']}-${entry['rank']}';

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  return index < 0 || index + 1 == arguments.length
      ? null
      : arguments[index + 1];
}

const _instructions = '''
You are a meticulous native Japanese language educator creating JLPT study data.
For every input item, return exactly one natural, self-contained Japanese example
sentence that demonstrates the supplied word in the supplied English sense.
Match sentence complexity roughly to the JLPT level. The answer may be a natural
inflected form of the target word. Include a kana reading of the full sentence,
an accurate natural English translation, and an accurate natural Korean
translation. Create quizSentence by replacing the first exact occurrence of
answer in sentence with ＿＿＿; change nothing else. Never omit, merge, reorder,
or invent an item, and copy each key exactly. Avoid offensive, sexual, violent,
political, or personally identifying content.
''';

const _schema = {
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'examples': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'key': {'type': 'string'},
          'sentence': {'type': 'string'},
          'reading': {'type': 'string'},
          'translations': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'en': {'type': 'string'},
              'ko': {'type': 'string'},
            },
            'required': ['en', 'ko'],
          },
          'quizSentence': {'type': 'string'},
          'answer': {'type': 'string'},
        },
        'required': [
          'key',
          'sentence',
          'reading',
          'translations',
          'quizSentence',
          'answer',
        ],
      },
    },
  },
  'required': ['examples'],
};
