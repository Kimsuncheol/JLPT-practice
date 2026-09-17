import 'package:flutter_test/flutter_test.dart';
import 'package:lib_llama_cpp/lib_llama_cpp.dart';
import 'package:lib_llama_cpp_platform_interface/lib_llama_cpp_platform_interface.dart';
import 'package:jlpt_practice/features/offline_ai/local_inference.dart';
import 'package:jlpt_practice/features/offline_ai/model_download.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';

// Opt-in real CPU inference smoke. Uses the same model, native worker and chat
// path as the app. A desktop success does not establish phone performance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const modelPath = String.fromEnvironment('JLPT_AI_MODEL_PATH');
  const libraryPath = String.fromEnvironment('JLPT_AI_LIBRARY_PATH');
  test(
    'pinned 1B model loads, generates twice, and releases native memory',
    () async {
      final model = OfflineAiModel.catalog.first;
      expect(
        await verifyModelFile(modelPath, model.bytes, model.sha256),
        isTrue,
      );
      final engine = LlamaLocalInference(
        engine: LibLlamaCpp(platform: _Library(libraryPath)),
      );
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
        // Visible evidence for manual quality review, not an accuracy benchmark.
        // ignore: avoid_print
        print('Native sample: $second');
      } finally {
        await engine.unload();
      }
    },
    skip: modelPath.isEmpty || libraryPath.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _Library extends LibLlamaCppPlatform {
  _Library(this.path);
  final String path;
  @override
  Future<LlamaCppLibraryDescriptor> resolveLibrary({
    LlamaCppLibraryRequest request = const LlamaCppLibraryRequest(),
  }) async => LlamaCppLibraryDescriptor(
    resolution: LlamaCppLibraryResolution.path,
    path: path,
    capabilities: const {LlamaCppLibraryCapability.cpu},
  );
}
