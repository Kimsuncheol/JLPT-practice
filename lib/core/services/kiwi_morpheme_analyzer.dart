import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_kiwi_nlp/flutter_kiwi_nlp.dart';
import 'package:jlpt_practice/core/services/meaning_mask_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const _modelAssetBase =
    'packages/flutter_kiwi_nlp/assets/kiwi-models/cong/base';

/// Bump when the bundled model changes so the cached copy is replaced.
const _modelVersion = 'kiwi-0.23.2-cong-base';

const _modelFiles = [
  'combiningRule.txt',
  'cong.mdl',
  'default.dict',
  'dialect.dict',
  'extract.mdl',
  'multi.dict',
  'sj.morph',
  'typo.dict',
];

/// Runs Kiwi in a background isolate so analysis never blocks the UI thread.
/// The isolate and model are created on first use and reused afterwards.
class KiwiMorphemeAnalyzer implements MorphemeAnalyzer {
  KiwiMorphemeAnalyzer({Future<String> Function()? modelDirectory})
    : _modelDirectory = modelDirectory ?? _installBundledModel;

  final Future<String> Function() _modelDirectory;

  // A failed start is remembered, so an unusable model is not re-copied on
  // every card; the caller falls back to substring matching instead.
  Future<_KiwiWorker>? _worker;
  bool _closed = false;

  @override
  Future<List<Morpheme>> analyze(String text) async {
    if (_closed) throw StateError('KiwiMorphemeAnalyzer is closed.');
    final worker = await (_worker ??= _start());
    return worker.analyze(text);
  }

  Future<_KiwiWorker> _start() async =>
      _KiwiWorker.spawn(await _modelDirectory());

  @override
  Future<void> close() async {
    _closed = true;
    final worker = _worker;
    if (worker == null) return;
    try {
      (await worker).dispose();
    } catch (_) {}
  }
}

/// Kiwi loads its model from files, not asset bundles, so the bundled model
/// is copied once into the app support directory.
Future<String> _installBundledModel() async {
  final directory = Directory(
    path.join(
      (await getApplicationSupportDirectory()).path,
      'kiwi',
      _modelVersion,
    ),
  );
  final marker = File(path.join(directory.path, '.complete'));
  if (marker.existsSync()) return directory.path;

  await directory.create(recursive: true);
  for (final name in _modelFiles) {
    final data = await rootBundle.load('$_modelAssetBase/$name');
    await File(path.join(directory.path, name)).writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }
  await marker.writeAsString(_modelVersion);
  return directory.path;
}

class _KiwiWorker {
  _KiwiWorker(this._isolate, this._commands);

  final Isolate _isolate;
  final SendPort _commands;

  static Future<_KiwiWorker> spawn(String modelDirectory) async {
    final responses = ReceivePort();
    final isolate = await Isolate.spawn(_kiwiWorkerMain, {
      'responses': responses.sendPort,
      'modelDir': modelDirectory,
    }, debugName: 'kiwi-morphology');
    try {
      final message = await responses.first;
      if (message case {'type': 'ready', 'port': final SendPort port}) {
        return _KiwiWorker(isolate, port);
      }
      if (message case {'type': 'error', 'error': final String error}) {
        throw StateError(error);
      }
      throw StateError('Kiwi worker did not initialize.');
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      rethrow;
    } finally {
      responses.close();
    }
  }

  Future<List<Morpheme>> analyze(String text) async {
    final reply = ReceivePort();
    _commands.send({'text': text, 'reply': reply.sendPort});
    try {
      final message = await reply.first;
      if (message case {'tokens': final List<Object?> tokens}) {
        return [
          for (final token in tokens)
            if (token case [
              final String form,
              final String tag,
              final int start,
              final int length,
            ])
              Morpheme(form: form, tag: tag, start: start, length: length),
        ];
      }
      if (message case {'error': final String error}) throw StateError(error);
      throw StateError('Kiwi returned an invalid response.');
    } finally {
      reply.close();
    }
  }

  void dispose() {
    _commands.send(null);
    _isolate.kill();
  }
}

void _kiwiWorkerMain(Map<String, Object> setup) async {
  final responses = setup['responses']! as SendPort;
  final commands = ReceivePort();
  KiwiAnalyzer? analyzer;
  try {
    analyzer = await KiwiAnalyzer.create(
      modelPath: setup['modelDir']! as String,
      numThreads: 1,
    );
    responses.send({'type': 'ready', 'port': commands.sendPort});
  } catch (error) {
    responses.send({'type': 'error', 'error': error.toString()});
    commands.close();
    return;
  }

  await for (final message in commands) {
    if (message == null) break;
    if (message case {
      'text': final String text,
      'reply': final SendPort reply,
    }) {
      try {
        final result = await analyzer.analyze(
          text,
          options: const KiwiAnalyzeOptions(),
        );
        final tokens = result.candidates.isEmpty
            ? const <KiwiToken>[]
            : result.candidates.first.tokens;
        reply.send({
          'tokens': [
            for (final token in tokens)
              [token.form, token.tag, token.start, token.length],
          ],
        });
      } catch (error) {
        reply.send({'error': error.toString()});
      }
    }
  }
  await analyzer.close();
  commands.close();
}
