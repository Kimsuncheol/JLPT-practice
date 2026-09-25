import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

typedef JlptCatalog = List<Vocabulary>;

class CatalogLoadException implements Exception {
  const CatalogLoadException(this.cause);
  final Object cause;
  String get userMessage => '사전 데이터를 불러오지 못했습니다';
  @override
  String toString() => userMessage;
}

JlptCatalog _parseCatalog(String raw) => (jsonDecode(raw) as List<dynamic>)
    .map((item) => Vocabulary.fromCatalogJson(item as Map<String, dynamic>))
    .toList(growable: false);

List<Vocabulary> _parseEnriched(String raw) =>
    (jsonDecode(raw) as List<dynamic>)
        .map((item) => Vocabulary.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

Future<JlptCatalog> loadJlptCatalog() async {
  try {
    final raw = await rootBundle.loadString('assets/data/jlpt_catalog.json');
    return await compute(_parseCatalog, raw);
  } on FormatException catch (error) {
    throw CatalogLoadException(error);
  } on TypeError catch (error) {
    throw CatalogLoadException(error);
  }
}

class VocabularyRepository {
  const VocabularyRepository();

  Future<List<Vocabulary>> load() async {
    final results = await Future.wait([
      rootBundle.loadString('assets/data/vocabulary.json'),
      loadJlptCatalog(),
    ]);
    final enriched = await compute(_parseEnriched, results[0] as String);
    final enrichedByPair = {
      for (final item in enriched) '${item.word}\u0000${item.reading}': item,
    };
    return (results[1] as JlptCatalog)
        .map((item) {
          final details = enrichedByPair['${item.word}\u0000${item.reading}'];
          return details == null ? item : item.enrichedWith(details);
        })
        .toList(growable: false);
  }
}
