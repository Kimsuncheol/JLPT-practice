import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart' hide AVAudioSessionCategory;
import 'package:crypto/crypto.dart';
import 'package:jlpt_practice/core/services/japanese_tts_voice.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:volume_controller/volume_controller.dart';

const _modelName = 'sherpa-onnx-supertonic-3-tts-int8-2026-05-11';
const _modelUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2';
const _modelArchiveBytes = 128774318;
const _modelArchiveSha256 =
    '82fa96f91c4ef8abaae3a14a3f4153facf88bed821d1f7331cec2700f432c427';

class JapaneseTtsService implements TtsService {
  JapaneseTtsService({
    required TtsVolumePreference Function() volumePreference,
    required this.voiceId,
  }) : _volumePreference = volumePreference,
       _fallback = TtsService(volumePreference: volumePreference);

  final TtsVolumePreference Function() _volumePreference;
  final String Function() voiceId;
  final TtsService _fallback;
  final AudioPlayer _player = AudioPlayer();

  Future<_JapaneseTtsWorker>? _worker;
  AudioSession? _audioSession;
  double? _systemVolumeToRestore;
  Completer<void>? _playbackCancelled;
  int _speechRequest = 0;
  bool _disposed = false;

  Future<bool> get isOfflineModelInstalled =>
      _JapaneseTtsModelManager.isInstalled();

  /// Downloads the official INT8 model once, then loads it in a dedicated
  /// isolate. Subsequent synthesis is fully offline.
  Future<void> prepare() async {
    if (_disposed) return;
    try {
      await (_worker ??= _createWorker());
    } catch (_) {
      _worker = null;
      rethrow;
    }
  }

  Future<_JapaneseTtsWorker> _createWorker() async {
    final modelDirectory = await _JapaneseTtsModelManager.ensureInstalled();
    return _JapaneseTtsWorker.spawn(modelDirectory);
  }

  @override
  Future<void> speak(String text) => speakWithVoice(text, voiceId());

  Future<void> speakWithVoice(String text, String voiceId) async {
    final speechText = prepareJapaneseTextForSpeech(text).trim();
    if (speechText.isEmpty || _disposed) return;
    if (_worker == null && !await _JapaneseTtsModelManager.isInstalled()) {
      await _fallback.speak(speechText);
      return;
    }
    final request = ++_speechRequest;
    _cancelPlaybackWait();
    await _player.stop();

    try {
      final worker = await (_worker ??= _createWorker());
      if (request != _speechRequest || _disposed) return;
      final voice = japaneseTtsVoiceById(voiceId);
      final wavPath = await worker.generate(text: speechText, sid: voice.sid);
      if (request != _speechRequest || _disposed) {
        await _deleteGeneratedFile(wavPath);
        return;
      }
      await _play(wavPath, request);
    } catch (_) {
      // A missing network connection on first use, unsupported native target,
      // or corrupt model must not make pronunciation unusable.
      _worker = null;
      if (request == _speechRequest && !_disposed) {
        await _fallback.speak(speechText);
      }
    }
  }

  @override
  Future<void> speakDialogue(List<DialogueTurn> turns) async {
    if (turns.isEmpty || _disposed) return;
    if (_worker == null && !await _JapaneseTtsModelManager.isInstalled()) {
      await _fallback.speakDialogue(turns);
      return;
    }
    final request = ++_speechRequest;
    _cancelPlaybackWait();
    await _player.stop();
    try {
      final worker = await (_worker ??= _createWorker());
      final baseVoice = japaneseTtsVoiceById(voiceId());
      for (final turn in turns) {
        if (request != _speechRequest || _disposed) return;
        final text = prepareJapaneseTextForSpeech(turn.text).trim();
        if (text.isEmpty) continue;
        final wavPath = await worker.generate(
          text: text,
          sid: baseVoice.sid,
          speed: (2 - turn.pitch).clamp(0.8, 1.2),
        );
        if (request != _speechRequest || _disposed) {
          await _deleteGeneratedFile(wavPath);
          return;
        }
        await _play(wavPath, request);
      }
    } catch (_) {
      _worker = null;
      if (request == _speechRequest && !_disposed) {
        await _fallback.speakDialogue(turns);
      }
    }
  }

  Future<void> _play(String wavPath, int request) async {
    final session = _audioSession ??= await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.duckOthers |
            AVAudioSessionCategoryOptions.interruptSpokenAudioAndMixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.assistanceNavigationGuidance,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      ),
    );
    final active = await session.setActive(true);
    if (!active || request != _speechRequest) {
      await _deleteGeneratedFile(wavPath);
      return;
    }

    try {
      await _applyVolumePreference();
      final completed = _player.onPlayerComplete.first;
      final cancelled = Completer<void>();
      _playbackCancelled = cancelled;
      await _player.play(DeviceFileSource(wavPath));
      await Future.any([completed, cancelled.future]);
      if (identical(_playbackCancelled, cancelled)) {
        _playbackCancelled = null;
      }
    } finally {
      await _deleteGeneratedFile(wavPath);
      if (request == _speechRequest) await _releaseAudioFocus();
    }
  }

  Future<void> _applyVolumePreference() async {
    final preference = _volumePreference();
    await _player.setVolume(1);
    if (preference.mode != TtsVolumeMode.slider) return;
    try {
      final controller = VolumeController.instance..showSystemUI = false;
      _systemVolumeToRestore ??= await controller.getVolume();
      await controller.setVolume(preference.level.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> _releaseAudioFocus() async {
    final previous = _systemVolumeToRestore;
    _systemVolumeToRestore = null;
    if (previous != null) {
      try {
        await (VolumeController.instance..showSystemUI = false).setVolume(
          previous,
        );
      } catch (_) {}
    }
    await _audioSession?.setActive(
      false,
      avAudioSessionSetActiveOptions:
          AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
    );
  }

  @override
  Future<void> stop() async {
    ++_speechRequest;
    _cancelPlaybackWait();
    await Future.wait([_player.stop(), _fallback.stop()]);
    await _releaseAudioFocus();
  }

  void _cancelPlaybackWait() {
    final cancelled = _playbackCancelled;
    _playbackCancelled = null;
    if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _player.dispose();
    await _fallback.dispose();
    final worker = _worker;
    if (worker != null) {
      try {
        (await worker).dispose();
      } catch (_) {}
    }
  }
}

Future<void> _deleteGeneratedFile(String filename) async {
  try {
    await File(filename).delete();
  } catch (_) {}
}

class _JapaneseTtsModelManager {
  static const _requiredFiles = [
    'duration_predictor.int8.onnx',
    'text_encoder.int8.onnx',
    'vector_estimator.int8.onnx',
    'vocoder.int8.onnx',
    'tts.json',
    'unicode_indexer.bin',
    'voice.bin',
  ];

  static Future<Directory> _root() async => Directory(
    path.join((await getApplicationSupportDirectory()).path, 'tts'),
  );

  static Future<bool> isInstalled() async {
    final model = Directory(path.join((await _root()).path, _modelName));
    return _requiredFiles.every(
      (relative) => File(path.join(model.path, relative)).existsSync(),
    );
  }

  static Future<Directory> ensureInstalled() async {
    final root = await _root();
    final model = Directory(path.join(root.path, _modelName));
    if (await isInstalled()) return model;
    await root.create(recursive: true);

    final archiveFile = File(path.join(root.path, '$_modelName.tar.bz2'));
    final partial = File('${archiveFile.path}.partial');
    if (partial.existsSync()) await partial.delete();

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_modelUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Model download failed with HTTP ${response.statusCode}',
        );
      }
      final sink = partial.openWrite();
      await response.pipe(sink);
    } finally {
      client.close(force: true);
    }

    await Isolate.run(
      () => _verifyAndExtractModelArchive(
        partial.path,
        archiveFile.path,
        root.path,
      ),
      debugName: 'japanese-tts-model-extract',
    );
    if (!await isInstalled()) {
      throw StateError('The Japanese TTS model is incomplete.');
    }
    return model;
  }
}

Future<void> _verifyAndExtractModelArchive(
  String partialPath,
  String archivePath,
  String outputPath,
) async {
  final partial = File(partialPath);
  final digest = await sha256.bind(partial.openRead()).first;
  if (partial.lengthSync() != _modelArchiveBytes ||
      digest.toString() != _modelArchiveSha256) {
    await partial.delete();
    throw const FormatException('Japanese TTS model checksum mismatch.');
  }
  final archive = File(archivePath);
  if (archive.existsSync()) await archive.delete();
  await partial.rename(archivePath);
  await extractFileToDisk(archivePath, outputPath);
  await archive.delete();
}

class _JapaneseTtsWorker {
  _JapaneseTtsWorker(this._isolate, this._commands);

  final Isolate _isolate;
  final SendPort _commands;
  var _nextId = 0;

  static Future<_JapaneseTtsWorker> spawn(Directory modelDirectory) async {
    final responses = ReceivePort();
    final isolate = await Isolate.spawn(_japaneseTtsWorkerMain, {
      'responses': responses.sendPort,
      'modelDir': modelDirectory.path,
    }, debugName: 'japanese-tts-engine');
    try {
      final message = await responses.first;
      if (message case {'type': 'ready', 'port': final SendPort port}) {
        return _JapaneseTtsWorker(isolate, port);
      }
      if (message case {'type': 'error', 'error': final String error}) {
        throw StateError(error);
      }
      throw StateError('Japanese TTS worker did not initialize.');
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      rethrow;
    } finally {
      responses.close();
    }
  }

  Future<String> generate({
    required String text,
    required int sid,
    double speed = 1,
  }) async {
    final id = _nextId++;
    final reply = ReceivePort();
    _commands.send({
      'type': 'generate',
      'id': id,
      'text': text,
      'sid': sid,
      'speed': speed,
      'reply': reply.sendPort,
    });
    try {
      final message = await reply.first;
      if (message case {'path': final String wavPath}) return wavPath;
      if (message case {'error': final String error}) throw StateError(error);
      throw StateError('Japanese TTS returned an invalid response.');
    } finally {
      reply.close();
    }
  }

  void dispose() {
    _commands.send({'type': 'dispose'});
    _isolate.kill();
  }
}

void _japaneseTtsWorkerMain(Map<String, Object> setup) async {
  final responses = setup['responses']! as SendPort;
  final modelDir = setup['modelDir']! as String;
  final commands = ReceivePort();
  sherpa_onnx.OfflineTts? tts;
  try {
    sherpa_onnx.initBindings();
    tts = sherpa_onnx.OfflineTts(
      sherpa_onnx.OfflineTtsConfig(
        model: sherpa_onnx.OfflineTtsModelConfig(
          supertonic: sherpa_onnx.OfflineTtsSupertonicModelConfig(
            durationPredictor: path.join(
              modelDir,
              'duration_predictor.int8.onnx',
            ),
            textEncoder: path.join(modelDir, 'text_encoder.int8.onnx'),
            vectorEstimator: path.join(modelDir, 'vector_estimator.int8.onnx'),
            vocoder: path.join(modelDir, 'vocoder.int8.onnx'),
            ttsJson: path.join(modelDir, 'tts.json'),
            unicodeIndexer: path.join(modelDir, 'unicode_indexer.bin'),
            voiceStyle: path.join(modelDir, 'voice.bin'),
          ),
          numThreads: 2,
        ),
        maxNumSenetences: 1,
      ),
    );
    responses.send({'type': 'ready', 'port': commands.sendPort});
  } catch (error) {
    responses.send({'type': 'error', 'error': error.toString()});
    commands.close();
    return;
  }

  await for (final message in commands) {
    if (message case {'type': 'dispose'}) break;
    if (message case {
      'type': 'generate',
      'id': final int id,
      'text': final String text,
      'sid': final int sid,
      'speed': final double speed,
      'reply': final SendPort reply,
    }) {
      try {
        final audio = tts.generateWithConfig(
          text: text,
          config: sherpa_onnx.OfflineTtsGenerationConfig(
            sid: sid,
            speed: speed,
            extra: const {'lang': 'ja'},
          ),
        );
        if (audio.samples.isEmpty || audio.sampleRate <= 0) {
          throw StateError('sherpa-onnx returned no audio.');
        }
        final wavPath = path.join(
          Directory.systemTemp.path,
          'jlpt-tts-${DateTime.now().microsecondsSinceEpoch}-$id.wav',
        );
        final written = sherpa_onnx.writeWave(
          filename: wavPath,
          samples: audio.samples,
          sampleRate: audio.sampleRate,
        );
        if (!written) throw StateError('Could not write generated audio.');
        reply.send({'path': wavPath});
      } catch (error) {
        reply.send({'error': error.toString()});
      }
    }
  }
  tts.free();
  commands.close();
}
