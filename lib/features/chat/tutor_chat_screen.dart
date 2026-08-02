import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/chat/tutor_chat_controller.dart';
import 'package:jlpt_practice/features/chat/tutor_chat_models.dart';

class TutorChatScreen extends ConsumerStatefulWidget {
  const TutorChatScreen({super.key});

  @override
  ConsumerState<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends ConsumerState<TutorChatScreen> {
  static const _learnerId = 'learner';
  static const _tutorId = 'kotoba-sensei';

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatController = InMemoryChatController();
  List<TutorChatMessage> _syncedMessages = const [];
  Set<String> _syncedTranslationLoadingIds = const {};
  bool _syncedGenerating = false;
  bool _hasSynced = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tutorChatControllerProvider, (previous, next) {
      final nextChat = next.value;
      if (nextChat != null) _syncChatController(nextChat);
      final previousCount = previous?.value?.messages.length ?? 0;
      final nextCount = nextChat?.messages.length ?? 0;
      final finishedGenerating =
          previous?.value?.isGenerating == true &&
          nextChat?.isGenerating == false;
      if (nextCount != previousCount ||
          nextChat?.isGenerating == true ||
          finishedGenerating) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
      }
    });
    final chat = ref.watch(tutorChatControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings('aiTutor')),
        actions: [
          IconButton(
            tooltip: context.strings('newConversation'),
            onPressed: chat.value?.messages.isNotEmpty == true
                ? _confirmClear
                : null,
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: chat.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _LoadError(
          onRetry: () => ref.invalidate(tutorChatControllerProvider),
        ),
        data: _buildChat,
      ),
    );
  }

  Widget _buildChat(TutorChatState chat) {
    _scheduleInitialSync(chat);
    final materialTheme = Theme.of(context);
    final scheme = materialTheme.colorScheme;
    final chatTheme = ChatTheme.fromThemeData(
      materialTheme,
    ).copyWith(shape: const BorderRadius.all(Radius.circular(20)));
    return Column(
      children: [
        _TutorControls(state: chat),
        if (chat.errorMessage != null)
          MaterialBanner(
            content: Text(chat.errorMessage!),
            actions: [
              TextButton(
                onPressed: () => ref
                    .read(tutorChatControllerProvider.notifier)
                    .dismissError(),
                child: Text(context.strings('dismiss')),
              ),
            ],
          ),
        Expanded(
          child: Chat(
            currentUserId: _learnerId,
            chatController: _chatController,
            theme: chatTheme,
            backgroundColor: scheme.surface,
            resolveUser: (id) async => User(
              id: id,
              name: id == _tutorId ? context.strings('aiTutor') : 'Learner',
            ),
            onMessageSend: chat.isGenerating
                ? (_) => ref
                      .read(tutorChatControllerProvider.notifier)
                      .stopGenerating()
                : _sendText,
            builders: Builders(
              emptyChatListBuilder: (_) => const _TutorWelcome(),
              chatAnimatedListBuilder: (context, itemBuilder) =>
                  ChatAnimatedList(
                    itemBuilder: itemBuilder,
                    scrollController: _scrollController,
                    topPadding: 12,
                    bottomPadding: 20,
                    scrollToBottomAppearanceThreshold: 80,
                    shouldScrollToEndWhenSendingMessage: true,
                    shouldScrollToEndWhenAtBottom: true,
                  ),
              composerBuilder: (_) => Composer(
                textEditingController: _messageController,
                hintText: context.strings('chatHint'),
                maxLines: 5,
                sendButtonVisibilityMode: chat.isGenerating
                    ? SendButtonVisibilityMode.always
                    : SendButtonVisibilityMode.disabled,
                allowEmptyMessage: chat.isGenerating,
                inputClearMode: chat.isGenerating
                    ? InputClearMode.never
                    : InputClearMode.always,
                sendIcon: Icon(
                  chat.isGenerating ? Icons.stop_rounded : Icons.send_rounded,
                ),
                sendIconColor: scheme.primary,
                inputFillColor: scheme.surfaceContainerHighest,
                backgroundColor: scheme.surface,
              ),
              textMessageBuilder:
                  (context, message, index, {isSentByMe = false, groupStatus}) {
                    if (isSentByMe) {
                      return SimpleTextMessage(
                        message: message,
                        index: index,
                        constraints: const BoxConstraints(maxWidth: 520),
                        sentBackgroundColor: scheme.primaryContainer,
                        sentTextStyle: materialTheme.textTheme.bodyLarge
                            ?.copyWith(color: scheme.onPrimaryContainer),
                        showTime: false,
                        showStatus: false,
                      );
                    }
                    final source = TutorChatMessage(
                      id: message.id,
                      role: TutorMessageRole.tutor,
                      text: message.text,
                      createdAt: message.createdAt ?? DateTime.now(),
                      translation: message.metadata?['translation'] as String?,
                    );
                    return _TutorMessageBubble(
                      message: source,
                      isStreaming:
                          message.metadata?['isStreaming'] as bool? ?? false,
                      isTranslating:
                          message.metadata?['isTranslating'] as bool? ?? false,
                    );
                  },
              chatMessageBuilder:
                  (
                    context,
                    message,
                    index,
                    animation,
                    child, {
                    isRemoved,
                    isSentByMe = false,
                    groupStatus,
                  }) => ChatMessage(
                    message: message,
                    index: index,
                    animation: animation,
                    isRemoved: isRemoved,
                    groupStatus: groupStatus,
                    horizontalPadding: 12,
                    verticalPadding: 7,
                    leadingWidget: isSentByMe
                        ? null
                        : CircleAvatar(
                            radius: 17,
                            backgroundColor: scheme.primaryContainer,
                            foregroundColor: scheme.onPrimaryContainer,
                            child: const Text(
                              '先',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                    child: child,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  void _sendText(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    ref.read(tutorChatControllerProvider.notifier).sendMessage(text);
  }

  void _send() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    _sendText(text);
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _scheduleInitialSync(TutorChatState chat) {
    if (_stateMatches(chat)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncChatController(chat);
    });
  }

  void _syncChatController(TutorChatState chat) {
    if (_stateMatches(chat) &&
        _chatController.messages.length == chat.messages.length) {
      return;
    }
    final lastIndex = chat.messages.length - 1;
    final messages = [
      for (var index = 0; index < chat.messages.length; index++)
        _toFlyerMessage(
          chat.messages[index],
          isStreaming: chat.isGenerating && index == lastIndex,
          isTranslating: chat.translationLoadingIds.contains(
            chat.messages[index].id,
          ),
        ),
    ];
    final animate = _chatController.messages.length != messages.length;
    _syncedMessages = chat.messages;
    _syncedGenerating = chat.isGenerating;
    _syncedTranslationLoadingIds = {...chat.translationLoadingIds};
    _hasSynced = true;
    unawaited(_chatController.setMessages(messages, animated: animate));
  }

  TextMessage _toFlyerMessage(
    TutorChatMessage message, {
    required bool isStreaming,
    required bool isTranslating,
  }) {
    return TextMessage(
      id: message.id,
      authorId: message.isUser ? _learnerId : _tutorId,
      createdAt: message.createdAt,
      text: message.text,
      metadata: {
        'translation': message.translation,
        'isStreaming': isStreaming,
        'isTranslating': isTranslating,
      },
    );
  }

  bool _stateMatches(TutorChatState chat) {
    if (!_hasSynced ||
        _syncedGenerating != chat.isGenerating ||
        _syncedTranslationLoadingIds.length !=
            chat.translationLoadingIds.length ||
        !_syncedTranslationLoadingIds.containsAll(chat.translationLoadingIds)) {
      return false;
    }
    final previous = _syncedMessages;
    final next = chat.messages;
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index++) {
      final a = previous[index];
      final b = next[index];
      if (a.id != b.id || a.text != b.text || a.translation != b.translation) {
        return false;
      }
    }
    return true;
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings('newConversation')),
        content: Text(context.strings('newConversationConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings('startNew')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(tutorChatControllerProvider.notifier).clearConversation();
    }
  }
}

class _TutorControls extends ConsumerWidget {
  const _TutorControls({required this.state});

  final TutorChatState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Row(
          children: [
            _ControlMenu<CorrectionMode>(
              icon: Icons.fact_check_outlined,
              label: strings(state.correctionMode.name),
              enabled: !state.isGenerating,
              values: CorrectionMode.values,
              valueLabel: (value) => strings(value.name),
              onSelected: ref
                  .read(tutorChatControllerProvider.notifier)
                  .setCorrectionMode,
            ),
            const SizedBox(width: 8),
            _ControlMenu<TutorScenario>(
              icon: Icons.theater_comedy_outlined,
              label: strings(state.scenario.name),
              enabled: !state.isGenerating,
              values: TutorScenario.values,
              valueLabel: (value) => strings(value.name),
              onSelected: ref
                  .read(tutorChatControllerProvider.notifier)
                  .setScenario,
            ),
            const SizedBox(width: 8),
            Consumer(
              builder: (context, ref, _) {
                final profile = ref.watch(appControllerProvider).value;
                return Chip(
                  avatar: const Icon(Icons.school_outlined, size: 18),
                  label: Text(profile?.selectedLevel ?? 'JLPT'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlMenu<T> extends StatelessWidget {
  const _ControlMenu({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.values,
    required this.valueLabel,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final List<T> values;
  final String Function(T value) valueLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) => ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
      ),
      menuChildren: values
          .map(
            (value) => MenuItemButton(
              onPressed: () => onSelected(value),
              child: Text(valueLabel(value)),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _TutorWelcome extends StatelessWidget {
  const _TutorWelcome();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 28),
        CircleAvatar(
          radius: 38,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Text('先生', style: TextStyle(fontSize: 24)),
        ),
        const SizedBox(height: 20),
        Text(
          strings('tutorWelcome'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          strings('tutorWelcomeBody'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    'こんにちは！自己紹介を練習したいです。',
                    'レストランで注文する練習をしましょう。',
                    '今日のことを日本語で話したいです。',
                  ]
                  .map(
                    (prompt) => ActionChip(
                      label: Text(prompt),
                      onPressed: () => context
                          .findAncestorStateOfType<_TutorChatScreenState>()
                          ?._sendPrompt(prompt),
                    ),
                  )
                  .toList(growable: false),
        ),
      ],
    );
  }
}

extension on _TutorChatScreenState {
  void _sendPrompt(String prompt) {
    _messageController.text = prompt;
    _send();
  }
}

class _TutorMessageBubble extends ConsumerWidget {
  const _TutorMessageBubble({
    required this.message,
    required this.isStreaming,
    required this.isTranslating,
  });

  final TutorChatMessage message;
  final bool isStreaming;
  final bool isTranslating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.text.isEmpty && isStreaming)
            IsTypingIndicator(size: 8, color: scheme.primary, spacing: 4)
          else
            SelectableText(
              message.text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if (message.translation != null) ...[
            const Divider(height: 22),
            Row(
              children: [
                Icon(Icons.translate, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  context.strings('translation'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: scheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(message.translation!),
          ],
          if (message.text.isNotEmpty && !isStreaming) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 2,
              children: [
                TextButton.icon(
                  onPressed: message.translation == null && !isTranslating
                      ? () => ref
                            .read(tutorChatControllerProvider.notifier)
                            .showTranslation(message.id)
                      : null,
                  icon: isTranslating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate, size: 18),
                  label: Text(
                    message.translation == null
                        ? context.strings('showTranslation')
                        : context.strings('translated'),
                  ),
                ),
                IconButton(
                  tooltip: context.strings('listen'),
                  onPressed: () =>
                      ref.read(ttsServiceProvider).speak(message.text),
                  icon: const Icon(Icons.volume_up_outlined, size: 20),
                ),
                IconButton(
                  tooltip: context.strings('copy'),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: message.text)),
                  icon: const Icon(Icons.copy_outlined, size: 19),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(context.strings('tutorLoadError')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.strings('retry')),
            ),
          ],
        ),
      ),
    );
  }
}
