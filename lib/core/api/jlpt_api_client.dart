import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final jlptApiClientProvider = Provider.autoDispose<JlptApiClient>((ref) {
  final client = JlptApiClient(
    baseUrl: const String.fromEnvironment(
      'JLPT_API_BASE_URL',
      defaultValue: 'https://jlpt-practice-langchain-muj9.onrender.com',
    ),
  );
  ref.onDispose(client.close);
  return client;
});

class JlptApiException implements Exception {
  const JlptApiException(this.messageKey);
  final String messageKey;
}

/// One client per screen scope; no content logging, response cache, or retries.
class JlptApiClient {
  JlptApiClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 130),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final Duration timeout;
  bool _closed = false;

  Uri _uri(String path) {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null ||
        !base.hasAuthority ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.scheme != 'https' && !(kDebugMode && base.scheme == 'http'))) {
      throw const JlptApiException('aiServiceUnavailable');
    }
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$path',
    );
  }

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (_closed) throw const JlptApiException('aiServiceUnavailable');
    final uri = _uri(path);
    if (body != null && utf8.encode(jsonEncode(body)).length > 16384) {
      throw const JlptApiException('aiRequestInvalid');
    }
    try {
      final headers = {
        'Accept': 'application/json',
        'Cache-Control': 'no-store',
      };
      final response =
          await (body == null
                  ? _client.get(uri, headers: headers)
                  : _client.post(
                      uri,
                      headers: {...headers, 'Content-Type': 'application/json'},
                      body: jsonEncode(body),
                    ))
              .timeout(timeout);
      if (response.statusCode == 429) {
        throw const JlptApiException('aiServiceBusy');
      }
      if (response.statusCode == 408 || response.statusCode == 504) {
        throw const JlptApiException('aiServiceTimeout');
      }
      if (response.statusCode == 422 ||
          response.statusCode == 400 ||
          response.statusCode == 413) {
        throw const JlptApiException('aiRequestInvalid');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const JlptApiException('aiServiceUnavailable');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return decoded;
    } on JlptApiException {
      rethrow;
    } on TimeoutException {
      throw const JlptApiException('aiServiceTimeout');
    } on FormatException {
      throw const JlptApiException('aiResponseInvalid');
    } catch (_) {
      throw const JlptApiException('aiServiceUnavailable');
    }
  }

  Future<bool> health() async => (await request('/health'))['status'] == 'ok';

  void close() {
    _closed = true;
    _client.close();
  }
}

String aiErrorKey(Object error) =>
    error is JlptApiException ? error.messageKey : 'aiServiceUnavailable';

String boundedText(String value, int length) =>
    String.fromCharCodes(value.runes.take(length));

String explanationLanguage(String language) => switch (language) {
  'ko' || 'Korean' => 'Korean',
  'ja' || 'Japanese' => 'Japanese',
  _ => 'English',
};
