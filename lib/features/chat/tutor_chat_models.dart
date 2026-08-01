enum TutorMessageRole { user, tutor }

enum CorrectionMode {
  gentle,
  balanced,
  strict;

  String get promptValue => switch (this) {
    gentle => 'Correct only mistakes that block understanding.',
    balanced =>
      'Correct important grammar, word choice, and naturalness issues without interrupting the conversation.',
    strict =>
      'Correct grammar, particles, register, word choice, and unnatural phrasing precisely.',
  };
}

enum TutorScenario {
  freeConversation,
  dailyLife,
  travel,
  workplace,
  jlpt;

  String get promptValue => switch (this) {
    freeConversation => 'a friendly free conversation',
    dailyLife => 'an everyday-life conversation in Japan',
    travel => 'a travel role-play in Japan',
    workplace => 'a Japanese workplace role-play',
    jlpt => 'a JLPT-oriented conversation and practice session',
  };
}

class TutorChatMessage {
  const TutorChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.translation,
  });

  final String id;
  final TutorMessageRole role;
  final String text;
  final DateTime createdAt;
  final String? translation;

  bool get isUser => role == TutorMessageRole.user;

  TutorChatMessage copyWith({String? text, String? translation}) {
    return TutorChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      createdAt: createdAt,
      translation: translation ?? this.translation,
    );
  }

  Map<String, Object?> toJson() => {
    'role': role.name,
    'text': text,
    'translation': translation,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory TutorChatMessage.fromJson(String id, Map<String, dynamic> json) {
    return TutorChatMessage(
      id: id,
      role: json['role'] == TutorMessageRole.tutor.name
          ? TutorMessageRole.tutor
          : TutorMessageRole.user,
      text: json['text'] as String? ?? '',
      translation: json['translation'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class TutorChatState {
  const TutorChatState({
    required this.messages,
    this.correctionMode = CorrectionMode.balanced,
    this.scenario = TutorScenario.freeConversation,
    this.isGenerating = false,
    this.translationLoadingIds = const {},
    this.errorMessage,
  });

  final List<TutorChatMessage> messages;
  final CorrectionMode correctionMode;
  final TutorScenario scenario;
  final bool isGenerating;
  final Set<String> translationLoadingIds;
  final String? errorMessage;

  TutorChatState copyWith({
    List<TutorChatMessage>? messages,
    CorrectionMode? correctionMode,
    TutorScenario? scenario,
    bool? isGenerating,
    Set<String>? translationLoadingIds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TutorChatState(
      messages: messages ?? this.messages,
      correctionMode: correctionMode ?? this.correctionMode,
      scenario: scenario ?? this.scenario,
      isGenerating: isGenerating ?? this.isGenerating,
      translationLoadingIds:
          translationLoadingIds ?? this.translationLoadingIds,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
