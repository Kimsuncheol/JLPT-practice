import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jlpt_practice/data/models/daily_lesson.dart';

final dailyLessonServiceProvider = Provider((ref) {
  final service = DailyLessonService();
  ref.onDispose(service.close);
  return service;
});

typedef LessonQuery = ({int page, String query});

final dailyLessonPageProvider = StreamProvider.autoDispose
    .family<LessonSnapshot<DailyLessonPage>, LessonQuery>(
      (ref, query) => ref
          .watch(dailyLessonServiceProvider)
          .pages(page: query.page, query: query.query),
    );

final dailyLessonDetailProvider = StreamProvider.autoDispose
    .family<LessonSnapshot<DailyLesson>, String>(
      (ref, id) => ref.watch(dailyLessonServiceProvider).lesson(id),
    );

class LessonSnapshot<T> {
  const LessonSnapshot(this.value, {this.saved = false, this.offline = false});
  final T value;
  final bool saved, offline;
}

/// Stores at most 30 responses, scoped to the configured server. Saved results
/// appear immediately while refreshing; transport failures retain saved content.
class DailyLessonService {
  DailyLessonService({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'JAPANESE_LESSON_API_BASE_URL',
      defaultValue: 'https://japanese-scraper.onrender.com',
    ),
    this.timeout = const Duration(seconds: 90),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;
  Future<SharedPreferences>? _preferences;
  String get _prefix => 'daily_lessons_v1:${Uri.encodeComponent(baseUrl)}:';

  Stream<LessonSnapshot<DailyLessonPage>> pages({
    int page = 1,
    String query = '',
  }) => _load('/api/articles', {
    'page': '$page',
    'status': 'ready',
    'q': query.trim(),
  }, DailyLessonPage.fromJson);

  Stream<LessonSnapshot<DailyLesson>> lesson(String id) => _load(
    '/api/articles/${Uri.encodeComponent(id)}',
    {},
    DailyLesson.fromJson,
  );

  Stream<LessonSnapshot<T>> _load<T>(
    String path,
    Map<String, String> parameters,
    T Function(Map<String, dynamic>) parse,
  ) async* {
    final base = Uri.parse(baseUrl);
    if (!base.hasAuthority ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.scheme != 'https' && !(kDebugMode && base.scheme == 'http'))) {
      throw const FormatException('Invalid lesson server address');
    }
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$path',
      queryParameters: parameters.isEmpty ? null : parameters,
    );
    final key = '$_prefix$uri';
    SharedPreferences? preferences;
    T? cached;
    try {
      preferences = await (_preferences ??= SharedPreferences.getInstance());
      final raw = preferences.getString(key);
      if (raw != null) cached = parse(jsonDecode(raw) as Map<String, dynamic>);
      if (cached == null && path.startsWith('/api/articles/')) {
        final id = Uri.decodeComponent(path.substring('/api/articles/'.length));
        for (final savedKey in preferences.getKeys().where(
          (k) => k.startsWith(_prefix),
        )) {
          try {
            final saved =
                jsonDecode(preferences.getString(savedKey)!)
                    as Map<String, dynamic>;
            for (final article in saved['articles'] as List? ?? []) {
              if (article['id'] == id) {
                cached = parse(article as Map<String, dynamic>);
                break;
              }
            }
          } catch (_) {
            /* Skip an unrelated or malformed saved response. */
          }
          if (cached != null) break;
        }
      }
    } catch (_) {
      // An unavailable or malformed cache must not block network access.
    }
    if (cached != null) yield LessonSnapshot(cached, saved: true);
    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(timeout);
      // Flask errors are HTML: check status before attempting to decode JSON.
      if (response.statusCode != 200) {
        throw const FormatException('Lesson unavailable');
      }
      final raw = utf8.decode(response.bodyBytes);
      final value = parse(jsonDecode(raw) as Map<String, dynamic>);
      if (preferences != null) {
        try {
          await preferences.remove(key);
          await preferences.setString(key, raw);
          final keys = preferences
              .getKeys()
              .where((k) => k.startsWith(_prefix))
              .toList();
          // Preserve the home feed when expiring older saved responses.
          final home =
              '$_prefix${base.replace(path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/api/articles', queryParameters: {'page': '1', 'status': 'ready', 'q': ''})}';
          for (final old
              in keys
                  .where((k) => k != key && k != home)
                  .take(keys.length > 30 ? keys.length - 30 : 0)) {
            await preferences.remove(old);
          }
        } catch (_) {
          // Cache persistence failure does not discard a valid response.
        }
      }
      yield LessonSnapshot(value);
    } catch (_) {
      if (cached == null) rethrow;
      yield LessonSnapshot(cached, saved: true, offline: true);
    }
  }

  void close() => _client.close();
}
