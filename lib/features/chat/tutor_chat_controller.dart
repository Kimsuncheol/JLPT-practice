import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/features/chat/tutor_ai_service.dart';
import 'package:jlpt_practice/features/chat/tutor_chat_models.dart';
import 'package:jlpt_practice/features/chat/tutor_chat_repository.dart';

final tutorChatRepositoryProvider = Provider<TutorChatRepository>(
  (ref) => const FirestoreTutorChatRepository(),
);

final tutorChatControllerProvider =
    AsyncNotifierProvider<TutorChatController, TutorChatState>(
      TutorChatController.new,
    );

class TutorChatController extends AsyncNotifier<TutorChatState> {
  late TutorChatRepository _repository;
  late TutorAiService _ai;
  late AppState _learner;
  StreamSubscription<String>? _activeSubscription;

  @override
  Future<TutorChatState> build() async {
    ref.onDispose(() => _activeSubscription?.cancel());
    _repository = ref.read(tutorChatRepositoryProvider);
    _learner = await ref.watch(appControllerProvider.future);
    _ai = await TutorAiService.create();
    List<TutorChatMessage> messages;
    try {
      messages = await _repository.loadMessages();
    } catch (_) {
      messages = const [];
    }
    final result = TutorChatState(messages: messages);
    _configure(result);
    return result;
  }

  TutorChatState get _value => state.requireValue;

  Future<void> sendMessage(String value) async {
    final text = value.trim();
    if (text.isEmpty || _value.isGenerating) return;

    final userMessage = TutorChatMessage(
      id: _id('user'),
      role: TutorMessageRole.user,
      text: text,
      createdAt: DateTime.now(),
    );
    final tutorMessage = TutorChatMessage(
      id: _id('tutor'),
      role: TutorMessageRole.tutor,
      text: '',
      createdAt: DateTime.now(),
    );
    state = AsyncData(
      _value.copyWith(
        messages: [..._value.messages, userMessage, tutorMessage],
        isGenerating: true,
        clearError: true,
      ),
    );
    unawaited(_saveSafely(userMessage));

    final completion = Completer<void>();
    var responseText = '';
    _activeSubscription = _ai
        .sendMessage(text)
        .listen(
          (chunk) {
            responseText = chunk.startsWith(responseText)
                ? chunk
                : '$responseText$chunk';
            _replaceMessage(tutorMessage.copyWith(text: responseText));
          },
          onError: (Object error, StackTrace stackTrace) {
            if (kDebugMode) {
              debugPrint('Tutor AI request failed: $error');
              debugPrintStack(stackTrace: stackTrace);
            }
            _activeSubscription = null;
            final messages = _value.messages
                .where((message) => message.id != tutorMessage.id)
                .toList(growable: false);
            state = AsyncData(
              _value.copyWith(
                messages: messages,
                isGenerating: false,
                errorMessage: _friendlyError(error),
              ),
            );
            if (!completion.isCompleted) completion.complete();
          },
          onDone: () {
            _activeSubscription = null;
            if (responseText.trim().isEmpty) {
              final messages = _value.messages
                  .where((message) => message.id != tutorMessage.id)
                  .toList(growable: false);
              state = AsyncData(
                _value.copyWith(
                  messages: messages,
                  isGenerating: false,
                  errorMessage:
                      'The tutor returned an empty response. Try again.',
                ),
              );
            } else {
              final completed = tutorMessage.copyWith(
                text: responseText.trim(),
              );
              _replaceMessage(completed, isGenerating: false);
              unawaited(_saveSafely(completed));
            }
            if (!completion.isCompleted) completion.complete();
          },
          cancelOnError: true,
        );
    await completion.future;
  }

  Future<void> stopGenerating() async {
    final subscription = _activeSubscription;
    if (subscription == null) return;
    await subscription.cancel();
    _activeSubscription = null;
    final messages = _value.messages
        .where((message) {
          return message.isUser || message.text.trim().isNotEmpty;
        })
        .toList(growable: false);
    state = AsyncData(_value.copyWith(messages: messages, isGenerating: false));
    if (messages.isNotEmpty && !messages.last.isUser) {
      unawaited(_saveSafely(messages.last));
    }
    _configure(_value);
  }

  Future<void> showTranslation(String messageId) async {
    final current = _value.messages.where((item) => item.id == messageId);
    if (current.isEmpty || current.first.translation != null) return;
    state = AsyncData(
      _value.copyWith(
        translationLoadingIds: {..._value.translationLoadingIds, messageId},
        clearError: true,
      ),
    );
    try {
      final translation = await _ai.translate(
        japanese: current.first.text,
        languageCode: _learner.meaningLanguage,
      );
      _replaceMessage(current.first.copyWith(translation: translation));
      await _repository.saveTranslation(messageId, translation);
    } catch (error) {
      state = AsyncData(_value.copyWith(errorMessage: _friendlyError(error)));
    } finally {
      state = AsyncData(
        _value.copyWith(
          translationLoadingIds: {..._value.translationLoadingIds}
            ..remove(messageId),
        ),
      );
    }
  }

  void setCorrectionMode(CorrectionMode mode) {
    if (_value.isGenerating) return;
    final next = _value.copyWith(correctionMode: mode);
    state = AsyncData(next);
    _configure(next);
  }

  void setScenario(TutorScenario scenario) {
    if (_value.isGenerating) return;
    final next = _value.copyWith(scenario: scenario);
    state = AsyncData(next);
    _configure(next);
  }

  Future<void> clearConversation() async {
    await stopGenerating();
    state = AsyncData(_value.copyWith(messages: const [], clearError: true));
    _configure(_value);
    await _repository.clearMessages();
  }

  void dismissError() {
    state = AsyncData(_value.copyWith(clearError: true));
  }

  void _configure(TutorChatState chatState) {
    _ai.configure(
      learner: _learner,
      correctionMode: chatState.correctionMode,
      scenario: chatState.scenario,
      history: chatState.messages,
    );
  }

  void _replaceMessage(TutorChatMessage replacement, {bool? isGenerating}) {
    final messages = _value.messages
        .map((message) => message.id == replacement.id ? replacement : message)
        .toList(growable: false);
    state = AsyncData(
      _value.copyWith(messages: messages, isGenerating: isGenerating),
    );
  }

  Future<void> _saveSafely(TutorChatMessage message) async {
    try {
      await _repository.saveMessage(message);
    } catch (_) {
      // Firestore persistence should not interrupt a live tutoring session.
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('quota') || raw.contains('429')) {
      return 'The tutor is busy right now. Please wait a moment and retry.';
    }
    if (raw.contains('app check') || raw.contains('unauthorized')) {
      return 'App Check could not verify this device. Check its registration and debug token.';
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return 'You appear to be offline. Reconnect and try again.';
    }
    return 'The tutor could not respond. Please try again.';
  }

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
}
