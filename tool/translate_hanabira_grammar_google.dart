import 'dart:convert';
import 'dart:io';

const _catalogPath = 'assets/data/jlpt_grammar.json';
const _endpoint = 'https://translate.googleapis.com/translate_a/single';

Future<void> main(List<String> arguments) async {
  final concurrency = int.parse(_option(arguments, '--concurrency') ?? '12');
  final force = arguments.contains('--force');
  final catalogFile = File(_catalogPath);
  final catalog = (jsonDecode(await catalogFile.readAsString()) as List)
      .cast<Map<String, dynamic>>();
  for (final entry in catalog) {
    entry['formationKo'] = entry['formation'];
  }
  final missing = force
      ? catalog
      : catalog
            .where((entry) => !_hasCompleteKorean(entry))
            .toList(growable: false);
  stdout.writeln(
    '${catalog.length - missing.length}/${catalog.length} already complete; '
    'translating ${missing.length}.',
  );

  final client = HttpClient();
  try {
    for (var offset = 0; offset < missing.length; offset += concurrency) {
      final end = (offset + concurrency).clamp(0, missing.length);
      final group = missing.sublist(offset, end);
      final translated = await Future.wait(
        group.map((entry) => _translateEntry(client, entry)),
      );
      for (var index = 0; index < group.length; index++) {
        _applyTranslation(group[index], translated[index]);
      }
      await _writeAtomically(catalogFile, catalog);
      stdout.writeln('Completed $end/${missing.length}.');
    }
  } finally {
    client.close(force: true);
  }

  await _writeAtomically(catalogFile, catalog);
  _validateComplete(catalog);
  stdout.writeln('Validated ${catalog.length} complete Korean translations.');
}

Future<List<String>> _translateEntry(
  HttpClient client,
  Map<String, dynamic> entry,
) async {
  final examples = (entry['examples'] as List).cast<Map<String, dynamic>>();
  final fields = <String>[
    entry['summary'] as String,
    entry['explanation'] as String,
    ...examples.map((example) => example['english'] as String),
  ];
  final protectedTokens = <String>[];
  final protectedFields = fields
      .map((field) => _protectJapanese(field, protectedTokens))
      .toList(growable: false);
  final input = StringBuffer(protectedFields.first);
  for (var index = 1; index < fields.length; index++) {
    input
      ..writeln()
      ..writeln('<<<JLPT_FIELD_$index>>>')
      ..write(protectedFields[index]);
  }

  Object? lastError;
  for (var attempt = 1; attempt <= 5; attempt++) {
    try {
      final uri = Uri.parse(_endpoint).replace(
        queryParameters: {
          'client': 'gtx',
          'sl': 'en',
          'tl': 'ko',
          'dt': 't',
          'q': input.toString(),
        },
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final decoded = jsonDecode(body) as List<dynamic>;
      final translatedText = StringBuffer();
      for (final segment in (decoded[0] as List<dynamic>)) {
        translatedText.write((segment as List<dynamic>)[0] as String);
      }
      final translated = translatedText
          .toString()
          .split(RegExp(r'\s*<<<JLPT_FIELD_\d+>>>\s*'))
          .map((value) => _restoreJapanese(value.trim(), protectedTokens))
          .toList(growable: false);
      if (translated.length != fields.length ||
          translated.any(
            (value) =>
                value.isEmpty ||
                RegExp(r'[\u0400-\u04ff\u0600-\u06ff]').hasMatch(value),
          )) {
        throw FormatException(
          '${entry['id']} returned ${translated.length}/${fields.length} fields',
        );
      }
      return translated;
    } catch (error) {
      lastError = error;
      if (attempt == 5) break;
      stderr.writeln('${entry['id']} failed (attempt $attempt/5): $error');
      await Future<void>.delayed(Duration(seconds: attempt * 2));
    }
  }
  throw StateError('${entry['id']} failed after 5 attempts: $lastError');
}

String _protectJapanese(String input, List<String> tokens) {
  return input.replaceAllMapped(RegExp(r'[\u3000-\u30ff\u3400-\u9fff々〆ヵヶー]+'), (
    match,
  ) {
    final index = tokens.length;
    tokens.add(match.group(0)!);
    return '<<<JPTOKEN_$index>>>';
  });
}

String _restoreJapanese(String input, List<String> tokens) {
  var restored = input;
  for (var index = 0; index < tokens.length; index++) {
    restored = restored.replaceAll('<<<JPTOKEN_$index>>>', tokens[index]);
  }
  if (restored.contains('<<<JPTOKEN_')) {
    throw const FormatException('A protected Japanese token was not restored');
  }
  return restored;
}

void _applyTranslation(Map<String, dynamic> entry, List<String> translated) {
  entry['summaryKo'] = translated[0];
  entry['explanationKo'] = translated[1];
  entry['formationKo'] = entry['formation'];
  final examples = (entry['examples'] as List).cast<Map<String, dynamic>>();
  for (var index = 0; index < examples.length; index++) {
    examples[index]['korean'] = translated[index + 2];
  }
}

bool _hasCompleteKorean(Map<String, dynamic> entry) {
  if ([
    'summaryKo',
    'explanationKo',
    'formationKo',
  ].any((field) => (entry[field] as String? ?? '').trim().isEmpty)) {
    return false;
  }
  return (entry['examples'] as List).cast<Map<String, dynamic>>().every(
    (example) => (example['korean'] as String? ?? '').trim().isNotEmpty,
  );
}

void _validateComplete(List<Map<String, dynamic>> catalog) {
  final ids = <String>{};
  for (final entry in catalog) {
    final id = entry['id'] as String;
    if (!ids.add(id)) throw StateError('Duplicate grammar id: $id');
    if (!_hasCompleteKorean(entry)) {
      throw StateError('Incomplete Korean translation: $id');
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

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  return index < 0 || index + 1 == arguments.length
      ? null
      : arguments[index + 1];
}
