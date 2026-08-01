import 'dart:convert';
import 'dart:io';

const _repository =
    'https://raw.githubusercontent.com/elzup/jlpt-word-list/master/src';

Future<void> main() async {
  final client = HttpClient();
  final output = <Map<String, Object>>[];

  try {
    for (var number = 1; number <= 5; number++) {
      final request = await client.getUrl(
        Uri.parse('$_repository/n$number.csv'),
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to download N$number: HTTP ${response.statusCode}',
        );
      }
      final raw = await utf8.decoder.bind(response).join();
      final rows = parseCsv(raw);
      var rank = 0;
      for (final row in rows.skip(1)) {
        if (row.length < 3) continue;
        final word = row[0].trim();
        final suppliedReading = row[1].trim();
        final reading = suppliedReading.isEmpty ? word : suppliedReading;
        final meaning = row[2].trim();
        if (word.isEmpty || reading.isEmpty || meaning.isEmpty) continue;
        rank++;
        output.add({
          'word': word,
          'reading': reading,
          'meaning': meaning,
          'level': 'N$number',
          'rank': rank,
        });
      }
      stdout.writeln('N$number: $rank words');
    }
  } finally {
    client.close();
  }

  final file = File('assets/data/jlpt_catalog.json');
  await file.writeAsString(jsonEncode(output));
  stdout.writeln('Wrote ${output.length} words to ${file.path}');
}

List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;

  void finishField() {
    row.add(field.toString());
    field.clear();
  }

  void finishRow() {
    finishField();
    if (row.any((value) => value.isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var index = 0; index < input.length; index++) {
    final character = input[index];
    if (character == '"') {
      if (quoted && index + 1 < input.length && input[index + 1] == '"') {
        field.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (character == ',' && !quoted) {
      finishField();
    } else if (character == '\n' && !quoted) {
      finishRow();
    } else if (character != '\r' || quoted) {
      field.write(character);
    }
  }

  if (field.isNotEmpty || row.isNotEmpty) finishRow();
  return rows;
}
