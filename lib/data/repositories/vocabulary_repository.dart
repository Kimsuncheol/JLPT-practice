import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

class VocabularyRepository {
  const VocabularyRepository();

  Future<List<Vocabulary>> load() async {
    final results = await Future.wait([
      rootBundle.loadString('assets/data/vocabulary.json'),
      rootBundle.loadString('assets/data/jlpt_catalog.json'),
    ]);
    final enriched = (jsonDecode(results[0]) as List<dynamic>)
        .map((item) => Vocabulary.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final enrichedByPair = {
      for (final item in enriched) '${item.word}\u0000${item.reading}': item,
    };
    return (jsonDecode(results[1]) as List<dynamic>)
        .map((item) => Vocabulary.fromCatalogJson(item as Map<String, dynamic>))
        .map((item) {
          final details = enrichedByPair['${item.word}\u0000${item.reading}'];
          return details == null ? item : item.enrichedWith(details);
        })
        .toList(growable: false);
  }
}
