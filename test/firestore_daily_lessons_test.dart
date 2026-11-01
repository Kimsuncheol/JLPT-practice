import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/api/daily_lesson_service.dart';
import 'package:jlpt_practice/features/daily_lessons/daily_lesson_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _lesson(int index) => {
  'id': 'article-${index.toString().padLeft(3, '0')}',
  'date': '2026-10-${(index ~/ 5 + 1).toString().padLeft(2, '0')}',
  'title': 'Lesson $index',
  'status': 'ready',
  'url': 'https://example.test/$index',
  '_synced_at': Timestamp.fromDate(DateTime(2026, 11, 2)),
  '_sync_hash': 'internal',
  'lesson': {
    'expressions': [
      {'japanese': '表現$index', 'reading': 'ひょうげん', 'translation': '표현$index'},
      {
        'japanese': '別の表現$index',
        'translation': index == 0 ? '오래된 표현' : '다른 표현$index',
      },
    ],
    'notes': ['Lesson note'],
    'uncertain_text': [],
  },
};

Future<void> _seed(FakeFirebaseFirestore db, int count) async {
  final batch = db.batch();
  for (var i = 0; i < count; i++) {
    final lesson = _lesson(i);
    batch.set(
      db.collection('japanese_lessons').doc(lesson['id'] as String),
      lesson,
    );
  }
  await batch.commit();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Firestore cursor pagination includes all days with stable same-date ordering',
    () async {
      final db = FakeFirebaseFirestore();
      await _seed(db, 37);
      await db.collection('japanese_lessons').doc('pending').set({
        ..._lesson(100),
        'status': 'pending',
      });
      final service = DailyLessonService(firestore: db);
      addTearDown(service.close);
      final ids = <String>[];
      var page = 1;
      while (true) {
        final result = (await service.pages(page: page).toList()).last;
        expect(result.value.lessons.length, lessThanOrEqualTo(10));
        ids.addAll(result.value.lessons.map((lesson) => lesson.id));
        if (page >= result.value.pages) break;
        page++;
      }
      expect(ids, [
        for (var i = 36; i >= 0; i--) 'article-${i.toString().padLeft(3, '0')}',
      ]);
      expect(ids.toSet().length, 37);
    },
  );

  test(
    'search finds secondary expressions in old documents beyond the first scan batch',
    () async {
      final db = FakeFirebaseFirestore();
      await _seed(db, 135);
      final service = DailyLessonService(firestore: db);
      addTearDown(service.close);
      final result = (await service.pages(query: '오래된 표현').toList()).last;
      expect(result.value.lessons.single.id, 'article-000');
      expect(result.value.lessons.single.expressions.length, 2);
      expect(result.value.pages, 1);
      expect(
        (await service.pages(query: 'no matching expression').toList())
            .last
            .value
            .lessons,
        isEmpty,
      );
    },
  );

  test(
    'Firestore lessons remain available from app storage after service restart',
    () async {
      final db = FakeFirebaseFirestore();
      await _seed(db, 3);
      final online = DailyLessonService(firestore: db);
      await online.pages().toList();
      await online.lesson('article-002').toList();
      online.close();
      // A separate denied instance simulates being unable to fetch from Firebase.
      final denied = FakeFirebaseFirestore(
        securityRules: '''
      service cloud.firestore { match /databases/{database}/documents {
        match /{document=**} { allow read, write: if false; }
      }}''',
      );
      final offline = DailyLessonService(firestore: denied);
      addTearDown(offline.close);
      final detail = await offline.lesson('article-002').toList();
      expect(detail.first.saved, isTrue);
      expect(detail.last.offline, isTrue);
      expect(detail.last.value.expressions.map((e) => e.japanese), [
        '表現2',
        '別の表現2',
      ]);
      // Verify sync timestamps do not prevent JSON persistence.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs
            .getKeys()
            .where((key) => key.startsWith('daily_lessons_v1:'))
            .length,
        2,
      );
    },
  );

  test(
    'lesson rules allow signed-in reads and reject every client write',
    () async {
      final rules = File('firestore.rules').readAsStringSync();
      expect(rules, contains('return request.auth != null;'));
      // The fake does not implement helper functions. Inline signedIn in the
      // actual collection block; Firebase compilation checks the complete file.
      final block =
          RegExp(r'match /japanese_lessons/\{articleId\} \{[\s\S]*?\n    \}')
              .firstMatch(rules)!
              .group(0)!
              .replaceAll('signedIn()', 'request.auth != null');
      final db = FakeFirebaseFirestore(
        securityRules:
            'service cloud.firestore { match /databases/{database}/documents { $block }}',
      );
      final doc = db.collection('japanese_lessons').doc('lesson');
      await expectLater(doc.get(), throwsException);
      db.authObject.add({
        'uid': 'learner',
        'token': {
          'firebase': {'sign_in_provider': 'password'},
        },
      });
      await doc.get();
      await expectLater(doc.set(_lesson(0)), throwsException);
      await expectLater(doc.delete(), throwsException);
    },
  );

  testWidgets(
    'Home and the lesson list display every expression from Firebase',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await _seed(db, 1);
      final service = DailyLessonService(firestore: db);
      addTearDown(service.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dailyLessonServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(
            home: Scaffold(body: LatestExpressionCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('表現0'), findsOneWidget);
      expect(find.text('別の表現0'), findsOneWidget);
      expect(find.text('오래된 표현'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dailyLessonServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(home: DailyLessonListScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('表現0'), findsOneWidget);
      expect(find.text('別の表現0'), findsOneWidget);
      expect(find.text('오래된 표현'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
