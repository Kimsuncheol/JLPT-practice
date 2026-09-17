import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_ai_service.dart';
import 'package:jlpt_practice/features/offline_ai/device_ai_capacity.dart';
import 'package:jlpt_practice/features/offline_ai/local_inference.dart';
import 'package:jlpt_practice/features/offline_ai/model_download.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_controller.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final bytes = utf8.encode('GGUF-test-model-fixture');
  late OfflineAiModel model;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('jlpt-offline-test-');
    model = OfflineAiModel(
      id: 'fixture',
      name: 'Test model',
      url: 'https://example.test/model.gguf',
      bytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      minimumRam: 4 * gib,
      loadBudget: 2 * gib,
    );
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('eligibility considers architecture, memory headroom, and heat', () {
    final capacity = _Probe(directory.path);
    expect(capacity.value.supports(model), isTrue);
    capacity.available = gib;
    expect(
      () => capacity.value.checkLoad(model),
      throwsA(_error('offlineLowMemory')),
    );
    capacity.available = 5 * gib;
    capacity.hot = true;
    expect(
      () => capacity.value.checkLoad(model),
      throwsA(_error('offlineTooHot')),
    );
    capacity.hot = false;
    capacity.bits64 = false;
    expect(capacity.value.supports(model), isFalse);
  });

  test('resumes exact byte range and promotes only a verified model', () async {
    final partial = File('${directory.path}/${model.filename}.part');
    await partial.writeAsBytes(bytes.take(5).toList());
    final downloader = ModelDownload(
      clientFactory: () => MockClient.streaming((request, _) async {
        expect(request.headers['Range'], 'bytes=5-');
        return http.StreamedResponse(
          Stream.value(bytes.sublist(5)),
          206,
          headers: {
            'content-range': 'bytes 5-${bytes.length - 1}/${bytes.length}',
            'content-length': '${bytes.length - 5}',
          },
        );
      }),
    );
    var verified = false;
    final file = await downloader.download(
      model,
      directory,
      onProgress: (_) {},
      onVerifying: () => verified = true,
      freeStorage: () async => gib,
    );
    expect(await file.readAsBytes(), bytes);
    expect(await partial.exists(), isFalse);
    expect(verified, isTrue);
  });

  test(
    'a server ignoring Range restarts without appending duplicate data',
    () async {
      await File(
        '${directory.path}/${model.filename}.part',
      ).writeAsBytes(bytes.take(5).toList());
      final downloader = ModelDownload(
        clientFactory: () =>
            MockClient((_) async => http.Response.bytes(bytes, 200)),
      );
      final file = await downloader.download(
        model,
        directory,
        onProgress: (_) {},
        onVerifying: () {},
        freeStorage: () async => gib,
      );
      expect(await file.readAsBytes(), bytes);
    },
  );

  test('wrong ranges never install a file', () async {
    final downloader = ModelDownload(
      clientFactory: () => MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.value(bytes),
          206,
          headers: {'content-range': 'bytes 5-10/20'},
        ),
      ),
    );
    await expectLater(
      downloader.download(
        model,
        directory,
        onProgress: (_) {},
        onVerifying: () {},
        freeStorage: () async => gib,
      ),
      throwsA(_error('offlineDownloadError')),
    );
    expect(await File('${directory.path}/${model.filename}').exists(), isFalse);
  });

  test('corrupt complete downloads are removed and cannot be loaded', () async {
    final corrupt = List<int>.of(bytes)..[0] = 0;
    final downloader = ModelDownload(
      clientFactory: () =>
          MockClient((_) async => http.Response.bytes(corrupt, 200)),
    );
    await expectLater(
      downloader.download(
        model,
        directory,
        onProgress: (_) {},
        onVerifying: () {},
        freeStorage: () async => gib,
      ),
      throwsA(_error('offlineIntegrityError')),
    );
    expect(await File('${directory.path}/${model.filename}').exists(), isFalse);
    expect(
      await File('${directory.path}/${model.filename}.part').exists(),
      isFalse,
    );
  });

  test('low storage stops before any network request', () async {
    var requests = 0;
    final downloader = ModelDownload(
      clientFactory: () => MockClient((_) async {
        requests++;
        return http.Response.bytes(bytes, 200);
      }),
    );
    await expectLater(
      downloader.download(
        model,
        directory,
        onProgress: (_) {},
        onVerifying: () {},
        freeStorage: () async => 0,
      ),
      throwsA(_error('offlineLowStorage')),
    );
    expect(requests, 0);
  });

  test(
    'truncated downloads keep a partial file for the next attempt',
    () async {
      final downloader = ModelDownload(
        clientFactory: () => MockClient.streaming(
          (_, _) async =>
              http.StreamedResponse(Stream.value(bytes.take(5).toList()), 200),
        ),
      );
      await expectLater(
        downloader.download(
          model,
          directory,
          onProgress: (_) {},
          onVerifying: () {},
          freeStorage: () async => gib,
        ),
        throwsA(_error('offlineDownloadError')),
      );
      expect(
        await File('${directory.path}/${model.filename}.part').length(),
        5,
      );
    },
  );

  test(
    'cancellation during verification preserves the complete partial',
    () async {
      final downloader = ModelDownload(
        clientFactory: () =>
            MockClient((_) async => http.Response.bytes(bytes, 200)),
      );
      await expectLater(
        downloader.download(
          model,
          directory,
          onProgress: (_) {},
          onVerifying: downloader.cancel,
          freeStorage: () async => gib,
        ),
        throwsA(_error('offlinePaused')),
      );
      expect(
        await File('${directory.path}/${model.filename}.part').length(),
        bytes.length,
      );
      expect(
        await File('${directory.path}/${model.filename}').exists(),
        isFalse,
      );
    },
  );

  test(
    'JSON fences and escaped braces are parsed; inconsistent grades are rejected',
    () {
      final valid = jsonEncode({
        'score': 2,
        'isCorrect': true,
        'feedback': 'Correct: "{quoted}".',
        'correctedSentence': '日本語を勉強します。',
      });
      expect(parseLocalGrammarFeedback('```json\n$valid\n```').score, 2);
      for (final raw in [
        '',
        '{"score":2}',
        '{broken}',
        valid.replaceFirst('"score":2', '"score":0'),
        valid.replaceFirst('"score":2', '"score":8'),
        valid.substring(0, valid.length - 1),
      ]) {
        expect(
          () => parseLocalGrammarFeedback(raw),
          throwsA(_error('offlineInvalidResponse')),
        );
      }
    },
  );

  test('prepare verifies and tests the model; inference reuses it', () async {
    await File('${directory.path}/${model.filename}').writeAsBytes(bytes);
    final engine = _Engine();
    final controller = OfflineAiController(
      probe: _Probe(directory.path),
      engine: engine,
      models: [model],
    );
    await controller.initialized;
    expect(await controller.prepare(), isTrue);
    expect(controller.ready, isTrue);
    expect(await controller.generate('system', 'input'), 'OK');
    expect(engine.loads, 1);
    expect(engine.generations, 2);
    await controller.remove(model);
    expect(controller.installed, isEmpty);
    expect(await File('${directory.path}/${model.filename}').exists(), isFalse);
    controller.dispose();
  });

  test('model load failures are recoverable and never report ready', () async {
    await File('${directory.path}/${model.filename}').writeAsBytes(bytes);
    final engine = _Engine()..failLoad = true;
    final controller = OfflineAiController(
      probe: _Probe(directory.path),
      engine: engine,
      models: [model],
    );
    await controller.initialized;
    expect(await controller.prepare(), isFalse);
    expect(controller.ready, isFalse);
    expect(controller.errorKey, 'offlineInferenceError');
    engine.failLoad = false;
    expect(await controller.prepare(), isTrue);
    controller.dispose();
  });

  test(
    'memory pressure discards in-flight feedback and releases the model',
    () async {
      await File('${directory.path}/${model.filename}').writeAsBytes(bytes);
      final engine = _Engine();
      final controller = OfflineAiController(
        probe: _Probe(directory.path),
        engine: engine,
        models: [model],
      );
      await controller.initialized;
      await controller.prepare();
      engine.pending = Completer<String>();
      final result = controller.generate('system', 'input');
      final assertion = expectLater(
        result,
        throwsA(_error('offlineLowMemory')),
      );
      await Future<void>.delayed(Duration.zero);
      controller.didHaveMemoryPressure();
      engine.pending!.complete('Ignore this result');
      await assertion;
      expect(controller.ready, isFalse);
      controller.dispose();
    },
  );

  testWidgets(
    'setup gate explains the download and does not enter tutor without a model',
    (tester) async {
      late OfflineAiController controller;
      await tester.runAsync(() async {
        controller = OfflineAiController(
          probe: _Probe(directory.path),
          engine: _Engine(),
        );
        await controller.initialized;
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineAiProvider.overrideWithValue(controller)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const OfflineAiGate(child: Text('Tutor opened')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offline grammar AI'), findsOneWidget);
      expect(find.text('Tutor opened'), findsNothing);
      expect(find.textContaining('0.81 GB'), findsOneWidget);
      expect(find.textContaining('2.02 GB'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Download model'), 250);
      expect(find.text('Download model'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}

Matcher _error(String key) =>
    isA<OfflineAiException>().having((e) => e.key, 'key', key);

class _Probe extends DeviceAiProbe {
  _Probe(this.directory);
  final String directory;
  int available = 5 * gib;
  bool hot = false;
  bool bits64 = true;
  DeviceAiCapacity get value => DeviceAiCapacity(
    totalRam: 8 * gib,
    availableRam: available,
    freeStorage: 10 * gib,
    is64Bit: bits64,
    hot: hot,
    directory: directory,
  );
  @override
  Future<DeviceAiCapacity> read() async => value;
}

class _Engine implements LocalInference {
  int loads = 0;
  int generations = 0;
  bool failLoad = false;
  Completer<String>? pending;
  @override
  Future<void> load(String path) async {
    loads++;
    if (failLoad) throw const OfflineAiException('offlineInferenceError');
  }

  @override
  Future<String> generate(String system, String input) async {
    generations++;
    return pending == null ? 'OK' : pending!.future;
  }

  @override
  Future<void> unload() async {}
}
