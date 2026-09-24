import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';

abstract class LocalInference {
  Future<void> load(String path);
  Future<String> generate(String system, String input);
  Future<void> unload();
}

/// Uses the verified app-owned model file without a second model-sized copy.
class GemmaLocalInference implements LocalInference {
  static Future<void>? _initialization;
  InferenceModel? _model;
  Future<void> _queue = Future.value();

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> load(String path) => _exclusive(() async {
    await _unload();
    try {
      await (_initialization ??= FlutterGemma.initialize(
        inferenceEngines: [LiteRtLmEngine()],
      ));
      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromFile(path).install();
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.cpu,
      );
    } catch (_) {
      _initialization = null;
      await _unload();
      throw const OfflineAiException('offlineInferenceError');
    }
  });

  @override
  Future<String> generate(String system, String input) => _exclusive(() async {
    final model = _model;
    if (model == null) {
      throw const OfflineAiException('offlineSetupRequired');
    }
    try {
      final chat = await model.createChat(
        systemInstruction: system,
        temperature: 0.1,
        topP: 0.9,
        maxOutputTokens: 320,
      );
      try {
        await chat.addQueryChunk(Message.text(text: input, isUser: true));
        final response = await chat.generateChatResponse();
        if (response is TextResponse) return response.token;
        throw const OfflineAiException('offlineInferenceError');
      } finally {
        await chat.close();
      }
    } on OfflineAiException {
      rethrow;
    } catch (_) {
      throw const OfflineAiException('offlineInferenceError');
    }
  });

  @override
  Future<void> unload() => _exclusive(_unload);

  Future<void> _unload() async {
    final model = _model;
    _model = null;
    if (model != null) await model.close();
  }
}
