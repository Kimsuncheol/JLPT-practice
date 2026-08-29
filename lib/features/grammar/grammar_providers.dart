import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/data/repositories/grammar_repository.dart';

final grammarRepositoryProvider = Provider((ref) => const GrammarRepository());

final grammarCatalogProvider = FutureProvider<List<GrammarPoint>>(
  (ref) => ref.read(grammarRepositoryProvider).load(),
);

final selectedGrammarLevelProvider = Provider<String>(
  (ref) => ref.watch(appControllerProvider).requireValue.selectedLevel,
);
