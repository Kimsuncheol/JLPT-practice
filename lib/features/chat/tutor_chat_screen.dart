import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tutorChatControllerProvider, (previous, next) {
      final previousCount = previous?.value?.messages.length ?? 0;
      final nextCount = next.value?.messages.length ?? 0;
      final finishedGenerating =
          previous?.value?.isGenerating == true &&
          next.value?.isGenerating == false;
      if (nextCount != previousCount ||
          next.value?.isGenerating == true ||
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
          child: chat.messages.isEmpty
              ? const _TutorWelcome()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: chat.messages.length,
                  itemBuilder: (context, index) => _MessageBubble(
                    message: chat.messages[index],
                    isStreaming:
                        chat.isGenerating && index == chat.messages.length - 1,
                    isTranslating: chat.translationLoadingIds.contains(
                      chat.messages[index].id,
                    ),
                  ),
                ),
        ),
        _Composer(
          controller: _messageController,
          isGenerating: chat.isGenerating,
          onSend: _send,
          onStop: () =>
              ref.read(tutorChatControllerProvider.notifier).stopGenerating(),
        ),
      ],
    );
  }

  void _send() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    ref.read(tutorChatControllerProvider.notifier).sendMessage(text);
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
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

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
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
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: BoxDecoration(
          color: isUser ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: isUser ? null : Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.text.isEmpty && isStreaming)
              const _TypingIndicator()
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
            if (!isUser && message.text.isNotEmpty && !isStreaming) ...[
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
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 38,
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (index) {
            final phase = (_controller.value - index * 0.16) * 2 * math.pi;
            final progress = (math.sin(phase) + 1) / 2;
            return Transform.scale(
              scale: 0.7 + progress * 0.3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.35 + progress * 0.65),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 9),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isGenerating,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: context.strings('chatHint'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: isGenerating
                  ? context.strings('stop')
                  : context.strings('send'),
              onPressed: isGenerating ? onStop : onSend,
              icon: Icon(
                isGenerating ? Icons.stop_rounded : Icons.send_rounded,
              ),
            ),
          ],
        ),
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
