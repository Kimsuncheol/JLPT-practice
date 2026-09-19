import 'dart:async';

import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';
import 'package:lib_llama_cpp/lib_llama_cpp.dart';

abstract class LocalInference {
  Future<void> load(String path);
  Future<String> generate(String system, String input);
  Future<void> unload();
}

/// One native worker at a time. Dispose is sent through the worker, so native
/// model/context allocations are freed before its isolate exits.
class LlamaLocalInference implements LocalInference {
  LlamaLocalInference({LlamaEngine? engine})
    : _engine = engine ?? const LibLlamaCpp();
  final LlamaEngine _engine;
  StreamController<LlamaCommand>? _commands;
  Completer<void>? _pending;
  Completer<void>? _closed;
  StringBuffer _text = StringBuffer();
  Future<void> _queue = Future.value();

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> load(String path) => _exclusive(() async {
    await _unload();
    _commands = StreamController<LlamaCommand>();
    _closed = Completer<void>();
    _engine
        .transform(_commandSequence(_commands!.stream))
        .listen(
          (event) {
            switch (event) {
              case LlamaTokenResponse(:final text):
                _text.write(text);
              case LlamaErrorResponse():
                _fail(const OfflineAiException('offlineInferenceError'));
              default:
                break;
            }
          },
          onError: (Object error, StackTrace stack) {
            _fail(const OfflineAiException('offlineInferenceError'));
          },
          onDone: () {
            _fail(const OfflineAiException('offlineInferenceError'));
            if (!_closed!.isCompleted) _closed!.complete();
          },
        );
    try {
      await _send(
        LlamaLoadModelCommand(
          modelPath: path,
          contextSize: 2048,
          gpuLayerCount: 0,
        ),
      );
    } catch (_) {
      await _unload();
      rethrow;
    }
  });

  // The pinned engine consumes commands serially with await-for. Resuming this
  // generator means its previous dispatch finished, even when generation emits
  // no LlamaDoneResponse. Capture the completer before yielding to avoid races.
  Stream<LlamaCommand> _commandSequence(Stream<LlamaCommand> input) async* {
    await for (final command in input) {
      final pending = _pending;
      yield command;
      if (pending != null && !pending.isCompleted) pending.complete();
    }
  }

  @override
  Future<String> generate(String system, String input) => _exclusive(() async {
    if (_commands == null || _closed!.isCompleted) {
      throw const OfflineAiException('offlineSetupRequired');
    }
    _text = StringBuffer();
    await _send(
      LlamaGenerateMessagesCommand(
        messages: [
          LlamaMessage(role: 'system', content: system),
          LlamaMessage(role: 'user', content: input),
        ],
        maxTokens: 320,
        temperature: 0.1,
        topP: 0.9,
      ),
    );
    return _text.toString();
  });

  Future<void> _send(LlamaCommand command) async {
    if (_closed?.isCompleted ?? true) {
      throw const OfflineAiException('offlineInferenceError');
    }
    final pending = Completer<void>();
    _pending = pending;
    _commands!.add(command);
    await pending.future;
  }

  void _fail(Object error) {
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.completeError(error);
    }
  }

  @override
  Future<void> unload() => _exclusive(_unload);

  Future<void> _unload() async {
    final commands = _commands;
    if (commands == null) return;
    if (!_closed!.isCompleted) {
      try {
        await _send(const LlamaDisposeCommand());
      } catch (_) {
        // A failed worker still needs its input stream closed.
      }
    }
    await commands.close();
    await _closed!.future;
    _commands = null;
    _pending = null;
  }
}
