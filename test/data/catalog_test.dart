import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Map<String, dynamic>> catalog;

  setUpAll(() {
    final decoded =
        jsonDecode(File('assets/data/jlpt_catalog.json').readAsStringSync())
            as List<dynamic>;
    catalog = decoded.cast<Map<String, dynamic>>();
  });

  test('catalog contains every upstream rank record', () {
    expect(catalog, hasLength(7972));
    expect(_count(catalog, 'N1'), 2699);
    expect(_count(catalog, 'N2'), 1748);
    expect(_count(catalog, 'N3'), 2139);
    expect(_count(catalog, 'N4'), 668);
    expect(_count(catalog, 'N5'), 718);
  });

  test('ranks are contiguous within each JLPT level', () {
    for (final level in ['N1', 'N2', 'N3', 'N4', 'N5']) {
      final ranks = catalog
          .where((word) => word['level'] == level)
          .map((word) => word['rank'] as int)
          .toList();
      expect(ranks, List<int>.generate(ranks.length, (index) => index + 1));
    }
  });

  test('every catalog record has required display data', () {
    for (final word in catalog) {
      expect(word['word'], isNotEmpty);
      expect(word['reading'], isNotEmpty);
      expect(word['meaning'], isNotEmpty);
    }
  });
}

int _count(List<Map<String, dynamic>> catalog, String level) =>
    catalog.where((word) => word['level'] == level).length;
