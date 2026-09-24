import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/data/repositories/vocabulary_repository.dart';

const minReorderTokens = 3;
const maxReorderTokens = 8;

typedef VocabEntry = Vocabulary;

class SentenceToken {
  const SentenceToken(this.id, this.text);
  final int id;
  final String text;
}

List<VocabEntry> entriesWithExamples(JlptCatalog catalog, {String? level}) =>
    catalog
        .where(
          (entry) =>
              (level == null || entry.jlptLevel == level) &&
              entry.example.sentence.trim().isNotEmpty,
        )
        .toList(growable: false);

List<SentenceToken> tokenizeExample(VocabEntry entry) => [
  for (final (index, token)
      in (entry.example.tokens ?? const <String>[]).indexed)
    SentenceToken(index, token),
];

bool isReorderEligible(VocabEntry entry) {
  final tokens = entry.example.tokens;
  if (tokens == null ||
      tokens.length < minReorderTokens ||
      tokens.length > maxReorderTokens ||
      tokens.any((token) => token.trim().isEmpty) ||
      tokens.toSet().length < 2) {
    return false;
  }
  final sentence = entry.example.sentence.replaceAll(
    RegExp(r'[。、！？!?，,．.：:；;「」『』（）()・…〜～\s]'),
    '',
  );
  return tokens.join() == sentence;
}

List<String> shuffleTokens(List<String> tokens, {Random? random}) {
  final shuffled = List<String>.of(tokens);
  if (tokens.length < 2 || tokens.toSet().length < 2) return shuffled;
  final rng = random ?? Random();
  for (var attempt = 0; attempt < 10; attempt++) {
    shuffled.shuffle(rng);
    if (!listEquals(shuffled, tokens)) return shuffled;
  }
  final different = shuffled.indexWhere((token) => token != shuffled.first);
  if (different > 0) {
    final first = shuffled[0];
    shuffled[0] = shuffled[different];
    shuffled[different] = first;
  }
  return shuffled;
}

class SentenceReorderQuiz {
  const SentenceReorderQuiz({
    required this.entry,
    required this.correctOrder,
    required this.shuffledTokens,
    required this.shuffledTiles,
    required this.meaningKo,
  });
  final VocabEntry entry;
  final List<String> correctOrder;
  final List<String> shuffledTokens;
  final List<SentenceToken> shuffledTiles;
  final String meaningKo;
}

SentenceReorderQuiz buildQuizFromEntry(VocabEntry entry, {Random? random}) {
  if (!isReorderEligible(entry)) throw ArgumentError('Ineligible example');
  final ordered = tokenizeExample(entry);
  final shuffled = List<SentenceToken>.of(ordered);
  final rng = random ?? Random();
  for (var attempt = 0; attempt < 10; attempt++) {
    shuffled.shuffle(rng);
    if (!listEquals(
      shuffled.map((tile) => tile.text).toList(),
      ordered.map((tile) => tile.text).toList(),
    )) {
      break;
    }
  }
  if (listEquals(
    shuffled.map((tile) => tile.text).toList(),
    ordered.map((tile) => tile.text).toList(),
  )) {
    final different = shuffled.indexWhere(
      (tile) => tile.text != shuffled.first.text,
    );
    final first = shuffled[0];
    shuffled[0] = shuffled[different];
    shuffled[different] = first;
  }
  return SentenceReorderQuiz(
    entry: entry,
    correctOrder: ordered.map((tile) => tile.text).toList(growable: false),
    shuffledTokens: shuffled.map((tile) => tile.text).toList(growable: false),
    shuffledTiles: shuffled,
    meaningKo: entry.example.translation('ko'),
  );
}

class SentenceReorderQuizSet {
  const SentenceReorderQuizSet({
    required this.quizzes,
    required this.requestedCount,
    required this.eligibleCount,
  });
  final List<SentenceReorderQuiz> quizzes;
  final int requestedCount;
  final int eligibleCount;
  int get actualCount => quizzes.length;
  bool get hasNoEligibleEntries => eligibleCount == 0;
}

SentenceReorderQuizSet buildQuizSet(
  List<VocabEntry> entries, {
  int count = 10,
  String? level,
  Random? random,
}) {
  final rng = random ?? Random();
  final seenIds = <String>{};
  final eligible = entries.where((entry) {
    if (level != null && entry.jlptLevel != level) return false;
    if (!isReorderEligible(entry)) {
      assert(() {
        debugPrint('Skipping ineligible reorder example: ${entry.id}');
        return true;
      }());
      return false;
    }
    return seenIds.add(entry.id);
  }).toList()..shuffle(rng);
  return SentenceReorderQuizSet(
    quizzes: eligible
        .take(max(0, count))
        .map((entry) => buildQuizFromEntry(entry, random: rng))
        .toList(growable: false),
    requestedCount: count,
    eligibleCount: eligible.length,
  );
}

bool isAnswerCorrect(List<String> userOrder, List<String> correctOrder) =>
    listEquals(userOrder, correctOrder);

class QuizAttemptResult {
  const QuizAttemptResult({
    required this.isCorrect,
    required this.wrongPositions,
  });
  final bool isCorrect;
  final List<int> wrongPositions;
}

QuizAttemptResult submitAnswer(
  SentenceReorderQuiz quiz,
  List<String> userOrder,
) {
  final wrong = <int>[];
  for (var index = 0; index < quiz.correctOrder.length; index++) {
    if (index >= userOrder.length ||
        userOrder[index] != quiz.correctOrder[index]) {
      wrong.add(index);
    }
  }
  for (
    var index = quiz.correctOrder.length;
    index < userOrder.length;
    index++
  ) {
    wrong.add(index);
  }
  return QuizAttemptResult(
    isCorrect: wrong.isEmpty && userOrder.length == quiz.correctOrder.length,
    wrongPositions: wrong,
  );
}

class QuizSessionSummary {
  final List<QuizSessionEntryResult> _results = [];
  List<QuizSessionEntryResult> get results => List.unmodifiable(_results);
  int get correct => _results.where((item) => item.result.isCorrect).length;
  int get total => _results.length;
  void add(SentenceReorderQuiz quiz, QuizAttemptResult result) =>
      _results.add(QuizSessionEntryResult(quiz.entry.id, result));
}

class QuizSessionEntryResult {
  const QuizSessionEntryResult(this.entryId, this.result);
  final String entryId;
  final QuizAttemptResult result;
}

Future<void> playQuizSentenceAudio(
  SentenceReorderQuiz quiz,
  TtsService service,
) async {
  try {
    await service.speak(quiz.entry.example.sentence);
  } catch (error) {
    debugPrint('Sentence reorder audio failed: $error');
  }
}
