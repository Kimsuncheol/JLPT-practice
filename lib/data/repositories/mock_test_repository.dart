import 'dart:math';

import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/data/models/quiz.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/data/repositories/quiz_repository.dart';

class MockTestRepository {
  MockTestRepository({QuizRepository? quizRepository, Random? random})
    : _quizRepository = quizRepository ?? QuizRepository(),
      _random = random ?? Random();

  final QuizRepository _quizRepository;
  final Random _random;

  List<QuizQuestion> buildVocabularySection(
    List<Vocabulary> source, {
    required String level,
    int count = 10,
  }) => _quizRepository.buildQuestions(source, count: count, level: level);

  List<GrammarQuestion> buildGrammarSection(
    List<GrammarPoint> source, {
    required String level,
    required String language,
    int count = 10,
  }) {
    final available =
        source.where((item) => item.level == level).toList()
          ..shuffle(_random);
    return available
        .take(count)
        .map((point) {
          final correctAnswer = point.localizedSummary(language);
          final distractors =
              available
                  .where(
                    (candidate) =>
                        candidate.id != point.id &&
                        candidate.localizedSummary(language) != correctAnswer,
                  )
                  .toList()
                ..shuffle(_random);
          final choices = <String>[
            correctAnswer,
            ...distractors.take(3).map((item) => item.localizedSummary(language)),
          ]..shuffle(_random);
          return GrammarQuestion(
            grammarPoint: point,
            choices: choices,
            correctAnswer: correctAnswer,
          );
        })
        .toList(growable: false);
  }
}
