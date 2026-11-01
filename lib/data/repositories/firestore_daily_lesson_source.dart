import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore is the authoritative archive. Cursor reads have no historical cap;
/// search scans batches until enough matches are found or the archive ends.
class FirestoreDailyLessonSource {
  FirestoreDailyLessonSource({this.firestore});

  final FirebaseFirestore? firestore;
  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;
  final _searches = <String, _ArchiveSearch>{};

  Future<Map<String, dynamic>> page(int page, String query) async {
    if (page < 1) throw const FormatException('Invalid lesson page');
    final text = query.trim().toLowerCase();
    if (page == 1) _searches.remove(text);
    final search = _searches.putIfAbsent(text, _ArchiveSearch.new);
    // Bound abandoned searches without limiting the number of archive pages.
    while (_searches.length > 6) {
      _searches.remove(_searches.keys.firstWhere((key) => key != text));
    }
    final required = page * 10 + 1;
    final batchSize = text.isEmpty ? 11 : 100;
    while (search.articles.length < required && !search.exhausted) {
      Query<Map<String, dynamic>> request = _db
          .collection('japanese_lessons')
          .orderBy('date', descending: true)
          .orderBy(FieldPath.documentId, descending: true);
      if (search.cursor != null) {
        request = request.startAfterDocument(search.cursor!);
      }
      final result = await request
          .limit(batchSize)
          .get(const GetOptions(source: Source.server));
      for (final doc in result.docs) {
        final article = _article(doc);
        if (article['status'] != 'ready') continue;
        if (text.isEmpty ||
            '${article['title']} ${jsonEncode(article['lesson'])}'
                .toLowerCase()
                .contains(text)) {
          search.articles.add(article);
        }
      }
      if (result.docs.isNotEmpty) search.cursor = result.docs.last;
      search.exhausted = result.docs.length < batchSize;
    }
    final start = (page - 1) * 10;
    final articles = search.articles.skip(start).take(10).toList();
    final more = search.articles.length > page * 10 || !search.exhausted;
    return {
      'articles': articles, 'page': page, 'pages': more ? page + 1 : page,
      // Exact when exhausted; otherwise the count already discovered so far.
      'total': search.articles.length,
    };
  }

  Future<Map<String, dynamic>> lesson(String id) async {
    if (id.isEmpty || id.contains('/')) {
      throw const FormatException('Invalid lesson ID');
    }
    final doc = await _db
        .collection('japanese_lessons')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists) throw const FormatException('Lesson not found');
    return _article(doc);
  }

  Map<String, dynamic> _article(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    // Internal sync timestamps are not part of the lesson or its JSON cache.
    return {
      'id': doc.id,
      for (final key in [
        'url',
        'date',
        'title',
        'status',
        'lesson',
        'images',
        'model',
        'processed_at',
      ])
        if (data.containsKey(key)) key: data[key],
    };
  }
}

class _ArchiveSearch {
  final articles = <Map<String, dynamic>>[];
  DocumentSnapshot<Map<String, dynamic>>? cursor;
  bool exhausted = false;
}
