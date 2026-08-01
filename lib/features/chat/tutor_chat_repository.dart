import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jlpt_practice/core/services/firebase_bootstrap.dart';
import 'package:jlpt_practice/features/chat/tutor_chat_models.dart';

abstract interface class TutorChatRepository {
  Future<List<TutorChatMessage>> loadMessages();
  Future<void> saveMessage(TutorChatMessage message);
  Future<void> saveTranslation(String messageId, String translation);
  Future<void> clearMessages();
}

class FirestoreTutorChatRepository implements TutorChatRepository {
  const FirestoreTutorChatRepository();

  CollectionReference<Map<String, dynamic>>? get _messages {
    final userId = FirebaseBootstrap.userId;
    if (!FirebaseBootstrap.isAvailable || userId == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('chatConversations')
        .doc('japanese-tutor')
        .collection('messages');
  }

  @override
  Future<List<TutorChatMessage>> loadMessages() async {
    final messages = _messages;
    if (messages == null) return const [];
    final snapshot = await messages.orderBy('createdAt').limitToLast(60).get();
    return snapshot.docs
        .map((doc) => TutorChatMessage.fromJson(doc.id, doc.data()))
        .where((message) => message.text.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> saveMessage(TutorChatMessage message) async {
    await _messages?.doc(message.id).set(message.toJson());
  }

  @override
  Future<void> saveTranslation(String messageId, String translation) async {
    await _messages?.doc(messageId).set({
      'translation': translation,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> clearMessages() async {
    final messages = _messages;
    if (messages == null) return;
    final snapshot = await messages.get();
    for (var start = 0; start < snapshot.docs.length; start += 400) {
      final batch = FirebaseFirestore.instance.batch();
      final end = (start + 400).clamp(0, snapshot.docs.length);
      for (final doc in snapshot.docs.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
