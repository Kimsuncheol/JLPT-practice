import 'package:jlpt_practice/data/models/vocabulary.dart';

class QuizQuestion {
  const QuizQuestion({required this.vocabulary, required this.choices});

  final Vocabulary vocabulary;
  final List<String> choices;
  String get correctAnswer => vocabulary.example.answer;
}

class QuizResult {
  const QuizResult({
    required this.total,
    required this.correct,
    required this.duration,
    required this.incorrectIds,
  });

  final int total;
  final int correct;
  final Duration duration;
  final List<String> incorrectIds;
  int get incorrect => total - correct;
  double get accuracy => total == 0 ? 0 : correct / total;
}
