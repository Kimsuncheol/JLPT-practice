class GrammarTutorFeedback {
  const GrammarTutorFeedback({
    required this.score,
    required this.isCorrect,
    required this.feedback,
    required this.correctedSentence,
  });

  final int score;
  final bool isCorrect;
  final String feedback;
  final String correctedSentence;
}

class GrammarPart {
  const GrammarPart({
    required this.number,
    required this.startRank,
    required this.endRank,
  });

  final int number;
  final int startRank;
  final int endRank;
}

GrammarPart grammarPartForRank(int rank) {
  final number = ((rank - 1) ~/ 10) + 1;
  return GrammarPart(
    number: number,
    startRank: (number - 1) * 10 + 1,
    endRank: number * 10,
  );
}
