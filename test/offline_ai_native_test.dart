import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/features/offline_ai/local_inference.dart';
import 'package:jlpt_practice/features/offline_ai/model_download.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';

// Opt-in real inference smoke. A desktop success does not establish phone
// performance or grading accuracy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const modelPath = String.fromEnvironment('JLPT_AI_MODEL_PATH');
  test(
    'pinned Gemma E2B model loads, generates twice, and releases memory',
    () async {
      final model = OfflineAiModel.catalog.first;
      expect(
        await verifyModelFile(modelPath, model.bytes, model.sha256),
        isTrue,
      );
      final engine = GemmaLocalInference();
      try {
        await engine.load(modelPath);
        final first = await engine.generate(
          'Answer briefly in English.',
          'Say hello in Japanese.',
        );
        expect(first.trim(), isNotEmpty);
        final second = await engine.generate(
          'Evaluate Japanese grammar. Answer with only JSON: {"score":2,"isCorrect":true,"feedback":"explanation","correctedSentence":"sentence"}.',
          'Target: ます (polite present). Sentence: 毎日日本語を勉強します。 Explain in English.',
        );
        expect(second.trim(), isNotEmpty);
        // ignore: avoid_print
        print('Native sample: $second');
      } finally {
        await engine.unload();
      }
    },
    skip: modelPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
