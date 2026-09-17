import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_qa_service.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';

/// Opens the "Ask about this grammar point" chat as a bottom sheet.
Future<void> showGrammarQaChatSheet(
  BuildContext context, {
  required GrammarPoint grammar,
  required String languageCode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _GrammarQaChatSheet(grammar: grammar, languageCode: languageCode),
  );
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromUser});
  final String text;
  final bool fromUser;
}

class _GrammarQaChatSheet extends ConsumerStatefulWidget {
  const _GrammarQaChatSheet({
    required this.grammar,
    required this.languageCode,
  });

  final GrammarPoint grammar;
  final String languageCode;

  @override
  ConsumerState<_GrammarQaChatSheet> createState() =>
      _GrammarQaChatSheetState();
}

class _GrammarQaChatSheetState extends ConsumerState<_GrammarQaChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _asking = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _asking) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _controller.clear();
      _asking = true;
    });
    _scrollToEnd();
    try {
      final service = await ref.read(grammarQaServiceProvider.future);
      final answer = await service.ask(
        grammar: widget.grammar,
        question: text,
        languageCode: widget.languageCode,
      );
      if (!mounted) return;
      setState(
        () => _messages.add(_ChatMessage(text: answer, fromUser: false)),
      );
    } catch (error) {
      if (!mounted) return;
      final key = error is OfflineAiException
          ? error.key
          : 'offlineInferenceError';
      setState(
        () => _messages.add(
          _ChatMessage(text: context.strings(key), fromUser: false),
        ),
      );
    } finally {
      if (mounted) setState(() => _asking = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.strings('askAboutThisGrammar'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _messages.isEmpty && !_asking
                  ? _EmptyState(onSuggestion: _send)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_asking ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: _TypingIndicator(),
                            ),
                          );
                        }
                        final message = _messages[index];
                        return _MessageBubble(
                          text: message.text,
                          fromUser: message.fromUser,
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_asking,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 300,
                        decoration: InputDecoration(
                          hintText: context.strings('askAboutThisGrammarHint'),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _asking ? null : () => _send(),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestion});

  final void Function(String suggestion) onSuggestion;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in [
                context.strings('askSuggestionWhenToUse'),
                context.strings('askSuggestionMoreExamples'),
                context.strings('askSuggestionDifference'),
              ])
                ActionChip(
                  label: Text(suggestion),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide.none,
                  onPressed: () => onSuggestion(suggestion),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? colors.primary : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          text,
          style: TextStyle(
            color: fromUser ? colors.onPrimary : colors.onSurface,
          ),
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
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: 32,
        height: 8,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final t = (_controller.value - index * 0.2) % 1.0;
              final bounce = 1 - (2 * t - 1).abs();
              return Opacity(
                opacity: 0.35 + 0.65 * bounce.clamp(0.0, 1.0),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
