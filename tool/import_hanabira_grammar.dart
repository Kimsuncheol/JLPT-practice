import 'dart:convert';
import 'dart:io';

const _repositoryBaseUrl =
    'https://raw.githubusercontent.com/tristcoil/hanabira.org/main/'
    'backend/express/json_data';
const _outputPath = 'assets/data/jlpt_grammar.json';

Future<void> main() async {
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
        final examples = (source['examples'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(
              (example) => {
                'japanese': example['jp'] as String,
                'romaji': example['romaji'] as String,
                'english': example['en'] as String,
              },
            )
            .toList(growable: false);
        output.add({
          'id': 'N${number}_${index + 1}',
          'level': 'N$number',
          'rank': index + 1,
          'title': source['title'] as String,
          'summary': source['short_explanation'] as String,
          'explanation': source['long_explanation'] as String,
          'formation': source['formation'] as String,
          'examples': examples,
        });
      }
      stdout.writeln('N$number: ${records.length} grammar points');
    }
  } finally {
    client.close(force: true);
  }

  final destination = File(_outputPath);
  final temporary = File('${destination.path}.tmp');
  await temporary.writeAsString(jsonEncode(output), flush: true);
  await temporary.rename(destination.path);
  stdout.writeln(
    'Wrote ${output.length} grammar points to ${destination.path}',
  );
}
