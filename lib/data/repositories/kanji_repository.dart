import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/data/models/kanji.dart';

List<Kanji> _parseKanji(String raw) => (jsonDecode(raw) as List<dynamic>)
    .map((item) => Kanji.fromJson(item as Map<String, dynamic>))
    .toList(growable: false);

Future<List<Kanji>> loadKanji() async {
  final raw = await rootBundle.loadString('assets/data/JLPT_Kanji.json');
  return compute(_parseKanji, raw);
}

/// Every kanji, in the order the data file lists them within each level.
final kanjiCatalogProvider = FutureProvider<List<Kanji>>((ref) => loadKanji());

List<Kanji> kanjiForLevel(List<Kanji> catalog, String level) =>
    catalog.where((item) => item.jlptLevel == level).toList(growable: false);
