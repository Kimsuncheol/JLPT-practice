import 'dart:math';

import 'package:jlpt_practice/data/models/quiz.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

class QuizRepository {
  QuizRepository({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<QuizQuestion> buildQuestions(
    List<Vocabulary> source, {
    int count = 10,
    String? level,
  }) {
    final available =
        source
            .where(
              (item) =>
                  (level == null || item.jlptLevel == level) &&
                  item.example.quizSentence.isNotEmpty &&
                  item.example.answer.isNotEmpty,
            )
            .toList()
          ..shuffle(_random);
    return available
        .take(count)
        .map((item) {
          final distractors =
              source
                  .where(
                    (candidate) =>
                        candidate.id != item.id &&
                        candidate.example.answer.isNotEmpty &&
                        candidate.example.answer != item.example.answer,
                  )
                  .toList()
                ..shuffle(_random);
          final choices = <String>[
            item.example.answer,
            ...distractors.take(3).map((word) => word.example.answer),
          ]..shuffle(_random);
          return QuizQuestion(vocabulary: item, choices: choices);
        })
        .toList(growable: false);
  }
}
