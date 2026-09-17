import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';

/// Downloads only catalog models into the application's private model directory.
/// Incomplete files survive cancellation and app restarts. No model is installed
/// until its entire pinned length and SHA-256 have been verified.
class ModelDownload {
  ModelDownload({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;
  final http.Client Function() _clientFactory;
  http.Client? _client;
  bool _cancelled = false;
  bool _running = false;

  void cancel() {
    _cancelled = true;
    _client?.close();
  }

  Future<File> download(
    OfflineAiModel model,
    Directory directory, {
    required void Function(int received) onProgress,
    required void Function() onVerifying,
    required Future<int> Function() freeStorage,
  }) async {
    if (_running) throw const OfflineAiException('offlineBusy');
    _running = true;
    _cancelled = false;
    final client = _clientFactory();
    _client = client;
    final partial = File('${directory.path}/${model.filename}.part');
    final target = File('${directory.path}/${model.filename}');
    RandomAccessFile? output;
    try {
      await directory.create(recursive: true);
      var received = await partial.exists() ? await partial.length() : 0;
      if (received > model.bytes) {
        await partial.delete();
        received = 0;
      }
      // No extraction or duplicate copy: promotion is an atomic rename.
      if (await freeStorage() < model.bytes - received + 256 * 1024 * 1024) {
        throw const OfflineAiException('offlineLowStorage');
      }
      onProgress(received);
      if (received < model.bytes) {
        final request = http.Request('GET', Uri.parse(model.url));
        request.headers['Accept-Encoding'] = 'identity';
        if (received > 0) request.headers['Range'] = 'bytes=$received-';
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 30));
        if (_cancelled) throw const OfflineAiException('offlinePaused');
        if (response.statusCode == 200) {
          received = 0; // Server ignored Range: truncate, never append.
          if (await freeStorage() < model.bytes + 256 * 1024 * 1024) {
            throw const OfflineAiException('offlineLowStorage');
          }
        } else if (response.statusCode == 206) {
          final range = response.headers['content-range'];
          if (range != 'bytes $received-${model.bytes - 1}/${model.bytes}') {
            throw const OfflineAiException('offlineDownloadError');
          }
        } else {
          throw const OfflineAiException('offlineDownloadError');
        }
        if (response.contentLength != null &&
            response.contentLength != model.bytes - received) {
          throw const OfflineAiException('offlineDownloadError');
        }
        output = await partial.open(
          mode: received == 0 ? FileMode.write : FileMode.append,
        );
        var lastProgress = DateTime.now();
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 30),
        )) {
          if (_cancelled) throw const OfflineAiException('offlinePaused');
          received += chunk.length;
          if (received > model.bytes) {
            throw const OfflineAiException('offlineIntegrityError');
          }
          await output.writeFrom(chunk);
          if (DateTime.now().difference(lastProgress).inMilliseconds >= 150) {
            onProgress(received);
            lastProgress = DateTime.now();
          }
        }
        await output.close();
        output = null;
      }
      if (_cancelled) throw const OfflineAiException('offlinePaused');
      if (await partial.length() != model.bytes) {
        throw const OfflineAiException('offlineDownloadError');
      }
      onProgress(model.bytes);
      onVerifying();
      final valid = await verifyModelFile(
        partial.path,
        model.bytes,
        model.sha256,
      );
      if (!valid) {
        await partial.delete();
        throw const OfflineAiException('offlineIntegrityError');
      }
      if (_cancelled) throw const OfflineAiException('offlinePaused');
      return await partial.rename(target.path);
    } on OfflineAiException {
      rethrow;
    } on Object {
      throw OfflineAiException(
        _cancelled ? 'offlinePaused' : 'offlineDownloadError',
      );
    } finally {
      await output?.close();
      client.close();
      _client = null;
      _running = false;
    }
  }
}

Future<bool> verifyModelFile(String path, int bytes, String expectedHash) =>
    Isolate.run(() async {
      final file = File(path);
      if (!await file.exists() || await file.length() != bytes) return false;
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString() == expectedHash;
    });
