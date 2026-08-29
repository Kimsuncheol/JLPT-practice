/// Parses RFC4180-style CSV text into rows of cells, handling quoted fields
/// with embedded commas, newlines, and doubled quotes as an escape for `"`.
List<List<String>> parseCsvRows(String raw) {
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  var i = 0;
  while (i < raw.length) {
    final char = raw[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < raw.length && raw[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field.write(char);
      i++;
      continue;
    }
    if (char == '"') {
      inQuotes = true;
      i++;
      continue;
    }
    if (char == ',') {
      row.add(field.toString());
      field = StringBuffer();
      i++;
      continue;
    }
    if (char == '\r') {
      i++;
      continue;
    }
    if (char == '\n') {
      row.add(field.toString());
      field = StringBuffer();
      rows.add(row);
      row = <String>[];
      i++;
      continue;
    }
    field.write(char);
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows.where((r) => r.any((cell) => cell.trim().isNotEmpty)).toList();
}

/// Builds a column-name-keyed cell lookup for a CSV row, given the header row.
String Function(List<String> row, String column) csvCellReader(
  List<String> header,
) {
  final columnIndex = {for (var i = 0; i < header.length; i++) header[i]: i};
  return (row, column) {
    final index = columnIndex[column];
    if (index == null || index >= row.length) return '';
    return row[index];
  };
}
