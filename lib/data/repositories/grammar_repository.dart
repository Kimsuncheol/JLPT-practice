import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';

class GrammarRepository {
  const GrammarRepository();

  Future<List<GrammarPoint>> load() async {
    final raw = await rootBundle.loadString('assets/data/jlpt_grammar.json');
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => GrammarPoint.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
