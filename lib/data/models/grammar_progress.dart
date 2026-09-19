enum GrammarMastery { newItem, learning, familiar, mastered }

class GrammarProgress {
  const GrammarProgress({
    required this.grammarId,
    required this.attempts,
    required this.correctAnswers,
    required this.productionScore,
    required this.lastPractisedAt,
    required this.nextReviewAt,
    this.lastMistake,
  });

  factory GrammarProgress.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return GrammarProgress(
      grammarId: json['grammarId'] as String? ?? '',
      attempts: json['attempts'] as int? ?? 0,
      correctAnswers: json['correctAnswers'] as int? ?? 0,
      productionScore: json['productionScore'] as int? ?? 0,
      lastMistake: json['lastMistake'] as String?,
      lastPractisedAt:
          DateTime.tryParse(json['lastPractisedAt'] as String? ?? '') ?? now,
      nextReviewAt:
          DateTime.tryParse(json['nextReviewAt'] as String? ?? '') ?? now,
    );
  }

  final String grammarId;
  final int attempts;
  final int correctAnswers;
  final int productionScore;
  final String? lastMistake;
  final DateTime lastPractisedAt;
  final DateTime nextReviewAt;

  double get accuracy => attempts == 0 ? 0 : correctAnswers / attempts;

  GrammarMastery get mastery {
    if (attempts == 0) return GrammarMastery.newItem;
    if (attempts >= 5 && accuracy >= .8 && productionScore >= 2) {
      return GrammarMastery.mastered;
    }
    if (attempts >= 3 && accuracy >= .6) return GrammarMastery.familiar;
    return GrammarMastery.learning;
  }

  bool get isDue => !nextReviewAt.isAfter(DateTime.now());

  Map<String, Object?> toJson() => {
    'grammarId': grammarId,
    'attempts': attempts,
    'correctAnswers': correctAnswers,
    'productionScore': productionScore,
    'lastMistake': lastMistake,
    'lastPractisedAt': lastPractisedAt.toUtc().toIso8601String(),
    'nextReviewAt': nextReviewAt.toUtc().toIso8601String(),
  };
}
