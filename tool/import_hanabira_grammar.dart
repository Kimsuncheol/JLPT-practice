import 'dart:convert';
import 'dart:io';

const _repositoryBaseUrl =
    'https://raw.githubusercontent.com/tristcoil/hanabira.org/main/'
    'backend/express/json_data';
const _outputPath = 'assets/data/jlpt_grammar.json';

Future<void> main() async {
  final destination = File(_outputPath);
  final previousTranslations = _loadPreviousTranslations(destination);
  final output = <Map<String, Object?>>[];
  final client = HttpClient();
  try {
    for (var number = 1; number <= 5; number++) {
      final uri = Uri.parse(
        '$_repositoryBaseUrl/grammar_ja_JLPT_N${number}_0001.json',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to download N$number grammar: HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      final records =
          (jsonDecode(await utf8.decoder.bind(response).join())
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      for (var index = 0; index < records.length; index++) {
        final source = records[index];
        final title = source['title'] as String;
        final id = 'N${number}_${index + 1}';
        final previous = previousTranslations[id];
        final previousExamples =
            (previous?['examples'] as Map<String, Map<String, String>>?) ??
            const {};
        final examples = (source['examples'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(
              (example) => {
                'japanese': example['jp'] as String,
                'reading': previousExamples[example['jp']]?['reading'],
                'romaji': example['romaji'] as String,
                'english': example['en'] as String,
                'korean': previousExamples[example['jp']]?['korean'],
              },
            )
            .toList(growable: false);
        output.add({
          'id': id,
          'level': 'N$number',
          'rank': index + 1,
          'title': title,
          'summary': source['short_explanation'] as String,
          'explanation': source['long_explanation'] as String,
          'formation': source['formation'] as String,
          'summaryKo': previous?['summaryKo'],
          'explanationKo': previous?['explanationKo'],
          'formationKo': previous?['formationKo'],
          'examples': examples,
        });
      }
      stdout.writeln('N$number: ${records.length} grammar points');
    }
  } finally {
    client.close(force: true);
  }

  final temporary = File('${destination.path}.tmp');
  await temporary.writeAsString(jsonEncode(output), flush: true);
  await temporary.rename(destination.path);
  stdout.writeln(
    'Wrote ${output.length} grammar points to ${destination.path}',
  );
}

Map<String, Map<String, Object?>> _loadPreviousTranslations(File file) {
  if (!file.existsSync()) return {};
  final records = (jsonDecode(file.readAsStringSync()) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  return {
    for (final record in records)
      record['id'] as String: {
        'summaryKo': record['summaryKo'],
        'explanationKo': record['explanationKo'],
        'formationKo': record['formationKo'],
        'examples': {
          for (final example
              in (record['examples'] as List).cast<Map<String, dynamic>>())
            example['japanese'] as String: {
              'reading': example['reading'] as String? ?? '',
              'korean': example['korean'] as String? ?? '',
            },
        },
      },
  };
}
