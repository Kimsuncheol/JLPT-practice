import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/features/chat/tutor_chat_models.dart';

class TutorAiService {
  TutorAiService._(this._modelName);

  static const fallbackModel = 'gemini-3.6-flash';

  final String _modelName;
  late GenerativeModel _model;
  late ChatSession _chat;

  static Future<TutorAiService> create() async {
    var modelName = fallbackModel;
    try {
      final config = FirebaseRemoteConfig.instance;
      await config.setDefaults(const {'ai_chat_model': fallbackModel});
      await config.fetchAndActivate();
      final configured = config.getString('ai_chat_model').trim();
      if (configured.isNotEmpty) modelName = configured;
    } catch (_) {
      // The stable fallback keeps chat available if Remote Config is offline.
    }
    return TutorAiService._(modelName);
  }

  void configure({
    required AppState learner,
    required CorrectionMode correctionMode,
    required TutorScenario scenario,
    required List<TutorChatMessage> history,
  }) {
    _model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      systemInstruction: Content.system(
        _systemInstruction(learner, correctionMode, scenario),
      ),
      generationConfig: GenerationConfig(
        maxOutputTokens: 700,
        temperature: 0.6,
      ),
    );
    final chatHistory = <Content>[];
    chatHistory.addAll(
      history
          .where((message) => message.text.trim().isNotEmpty)
          .map(
            (message) => message.isUser
                ? Content.text(message.text)
                : Content.model([TextPart(message.text)]),
          ),
    );
    _chat = _model.startChat(history: chatHistory, maxTurns: 30);
  }

  Stream<String> sendMessage(String text) {
    return _chat
        .sendMessageStream(Content.text(text))
        .map((response) => response.text ?? '')
        .where((chunk) => chunk.isNotEmpty);
  }

  Future<String> translate({
    required String japanese,
    required String languageCode,
  }) async {
    final language = languageCode == 'ko' ? 'Korean' : 'English';
    final response = await _model.generateContent([
      Content.text(
        'Translate the Japanese tutor message below into natural $language. '
        'Preserve its teaching intent and line breaks. Return only the '
        'translation, with no preface or commentary.\n\n$japanese',
      ),
    ]);
    final result = response.text?.trim();
    if (result == null || result.isEmpty) {
      throw StateError('The tutor did not return a translation.');
    }
    return result;
  }

  String _systemInstruction(
    AppState learner,
    CorrectionMode correctionMode,
    TutorScenario scenario,
  ) {
    final explanationLanguage = learner.meaningLanguage == 'ko'
        ? 'Korean'
        : 'English';
    final readingRule = learner.showFurigana
        ? 'For kanji likely above ${learner.selectedLevel}, add a reading once '
              'in the form 漢字（かんじ）. Do not add romaji.'
        : 'Use normal Japanese without inline readings or romaji.';
    return '''
You are Kotoba Sensei, a warm and precise Japanese tutor.
The learner is studying ${learner.selectedLevel}. Adapt vocabulary, grammar,
sentence length, and politeness to that level. The session is ${scenario.promptValue}.

Always respond primarily in natural Japanese. Keep turns short enough for a
learner to answer. End with exactly one useful Japanese question or retry task.
$readingRule

Correction policy: ${correctionMode.promptValue}
When correction is needed, first respond naturally, then add a compact section
headed 「訂正」. Show the learner's phrase, the corrected phrase, and one short
reason in $explanationLanguage. Clearly distinguish an actual error from a
merely more-natural alternative. Ask the learner to retry the corrected idea.
If no correction is needed, do not invent one and do not add the section.

Do not provide a full translation unless the learner explicitly asks for one.
Do not use Markdown tables, code fences, or claim certainty about cultural
nuance when multiple usages are reasonable.
''';
  }
}
