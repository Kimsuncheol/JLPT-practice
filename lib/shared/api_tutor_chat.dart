import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/core/api/jlpt_tutor_service.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/shared/chat_ui_style.dart';

class ApiTutorChat extends ConsumerStatefulWidget {
  const ApiTutorChat({
    required this.title,
    required this.icon,
    required this.hint,
    required this.suggestionKeys,
    required this.closeKey,
    required this.level,
    required this.language,
    this.contextData = const {},
    this.contextBuilder,
    this.practiceItem = false,
    this.initialMessage,
    this.initialReplyLoader,
    this.showInitialMessage = false,
    this.sendKey,
    this.onContinue,
    this.onPractice,
    super.key,
  });

  final String title, hint, level, language;
  final IconData icon;
  final List<String> suggestionKeys;
  final Key closeKey;
  final Key? sendKey;
  final Map<String, dynamic> contextData;
  final Map<String, dynamic> Function()? contextBuilder;
  final bool practiceItem;
  final String? initialMessage;

  /// Optional structured first turn; subsequent turns use the tutor endpoint.
  final Future<TutorReply> Function(JlptApiClient client)? initialReplyLoader;
  final bool showInitialMessage;
  final VoidCallback? onContinue, onPractice;

  @override
  ConsumerState<ApiTutorChat> createState() => _ApiTutorChatState();
}

class _ApiTutorChatState extends ConsumerState<ApiTutorChat> {
  static const _user = ChatUser(id: 'user', firstName: 'You');
  static const _ai = ChatUser(id: 'ai', firstName: 'AI');
  final _messages = ChatMessagesController(
    paginationConfig: const PaginationConfig(reverseOrder: false),
  );
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _followBottom = true;
  bool _bottomFrameScheduled = false;
  final List<TutorTurn> _history = [];
  bool _busy = false;
  String? _error, _failedMessage;
  String? _shownUserMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage case final message?) {
      Future<void>.microtask(
        () => _send(message, showUser: widget.showInitialMessage),
      );
    }
  }

  @override
  void dispose() {
    _messages.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Bypass the package's manual-scroll debounce for an explicit send action.
  // Metrics notifications keep the bottom anchored as replies/keyboard resize.
  void _pinToBottom() {
    if (_bottomFrameScheduled || !mounted || !_followBottom) return;
    _bottomFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomFrameScheduled = false;
      if (!mounted || !_followBottom || !_scroll.hasClients) return;
      final position = _scroll.position;
      if ((position.maxScrollExtent - position.pixels).abs() > 0.5) {
        _scroll.jumpTo(position.maxScrollExtent);
        _pinToBottom();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _send(String value, {bool showUser = true}) async {
    final message = value.trim();
    if (!mounted || _busy || message.isEmpty || message.runes.length > 500) {
      return;
    }
    _followBottom = true;
    _pinToBottom();
    setState(() {
      _busy = true;
      _error = null;
      _failedMessage = null;
    });
    if (showUser && _shownUserMessage != message) {
      _messages.addMessage(
        ChatMessage(text: message, user: _user, createdAt: DateTime.now()),
      );
      _shownUserMessage = message;
    }
    try {
      final service = JlptTutorService(ref.read(jlptApiClientProvider));
      final contextData = widget.contextBuilder?.call() ?? widget.contextData;
      final initialLoader = widget.initialReplyLoader;
      final reply = _history.isEmpty && initialLoader != null
          ? await initialLoader(service.client)
          : await service.fetchReply(
              practiceItem: widget.practiceItem,
              level: widget.level,
              language: widget.language,
              context: contextData,
              message: message,
              history: List.of(_history),
            );
      if (!mounted) return;
      final answer = ChatMessage(
        text: reply.text,
        user: _ai,
        createdAt: DateTime.now(),
        isMarkdown: true,
        customProperties: {
          'id': 'ai_${DateTime.now().microsecondsSinceEpoch}',
          'isStreaming': false,
          'followUpQuestions': reply.followUpQuestions,
          'followUpsLoading': reply.followUpQuestions.isEmpty,
        },
      );
      _messages.addMessage(answer);
      _messages.stopStreamingMessage(answer.customProperties!['id'] as String);
      _shownUserMessage = null;
      _history.addAll([
        TutorTurn(isUser: true, text: message),
        TutorTurn(isUser: false, text: reply.text),
      ]);
      if (_history.length > 6) _history.removeRange(0, _history.length - 6);
      if (_input.text.trim() == message) _input.clear();
      if (reply.followUpQuestions.isEmpty) {
        _loadFollowUps(service, answer, contextData, List.of(_history));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = aiErrorKey(error);
          _failedMessage = message;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _pinToBottom();
      }
    }
  }

  Future<void> _loadFollowUps(
    JlptTutorService service,
    ChatMessage answer,
    Map<String, dynamic> contextData,
    List<TutorTurn> history,
  ) async {
    List<String> questions;
    try {
      questions = await service.suggestFollowUps(
        practiceItem: widget.practiceItem,
        level: widget.level,
        language: widget.language,
        context: contextData,
        history: history,
      );
    } catch (_) {
      // Suggestion failure must not turn a successful tutor reply into an error.
      questions = const [];
    }
    if (!mounted) return;
    _messages.updateMessage(
      answer.copyWith(
        customProperties: {
          ...?answer.customProperties,
          'followUpQuestions': questions,
          'followUpsLoading': false,
        },
      ),
    );
    _pinToBottom();
  }

  Widget? _followUpFooter(
    BuildContext context,
    ChatMessage message,
    bool isUser,
  ) {
    if (isUser) return null;
    final questions =
        message.customProperties?['followUpQuestions'] as List<String>? ??
        const [];
    if (message.customProperties?['followUpsLoading'] == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.strings('aiLoadingFollowUps'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    if (questions.isEmpty) return null;
    final theme = Theme.of(context);
    final followUpBackground = Color.lerp(
      theme.colorScheme.surfaceContainerHigh,
      Colors.black,
      theme.brightness == Brightness.dark ? 0.30 : 0.08,
    )!;
    return Padding(
      key: ValueKey('followups_${message.customProperties?['id']}'),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final question in questions)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton(
                onPressed: _busy ? null : () => _send(question),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  backgroundColor: followUpBackground,
                  disabledBackgroundColor: followUpBackground,
                  minimumSize: const Size(double.infinity, 56),
                  padding: const EdgeInsets.all(16),
                  shape: const RoundedRectangleBorder(
                    borderRadius: ChatUiStyle.aiBubbleBorderRadius,
                  ),
                ),
                child: Text(question),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _suggestions() => [
    for (final key in widget.suggestionKeys)
      ChatUiStyle.suggestion(
        context.strings(key),
        _busy ? null : () => _send(context.strings(key)),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    // Keep the client alive for this screen; autoDispose closes it on exit.
    ref.watch(jlptApiClientProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
        title: ChatUiStyle.appBarTitle(context, widget.icon, widget.title),
        actions: [
          if (widget.onPractice != null)
            IconButton(
              tooltip: context.strings('aiFocusedPractice'),
              onPressed: _busy ? null : widget.onPractice,
              icon: const Icon(Icons.quiz_outlined),
            ),
          IconButton(
            key: widget.closeKey,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.strings('temporaryChatNotice'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ChatUiStyle.appBarDivider(context),
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      if (notification.direction != ScrollDirection.idle) {
                        _followBottom = false;
                      }
                      return false;
                    },
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: (_) {
                        _pinToBottom();
                        return false;
                      },
                      child: AiChatWidget(
                        scrollController: _scroll,
                        paginationConfig: const PaginationConfig(
                          reverseOrder: false,
                        ),
                        enableMarkdownStreaming: false,
                        scrollToBottomOptions: ScrollToBottomOptions(
                          scrollToBottomBuilder: (_) => Positioned(
                            bottom: 12,
                            right: 16,
                            child: IconButton.filled(
                              key: const ValueKey('chat_pin_to_bottom'),
                              tooltip: context.strings('scrollToBottom'),
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () {
                                _followBottom = true;
                                _pinToBottom();
                              },
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                            ),
                          ),
                        ),
                        scrollBehaviorConfig: const ScrollBehaviorConfig(
                          autoScrollBehavior: AutoScrollBehavior.never,
                        ),
                        currentUser: _user,
                        aiUser: _ai,
                        controller: _messages,
                        onSendMessage: (message) => _send(message.text),
                        readOnly: true,
                        loadingConfig: ChatUiStyle.loading(context, _busy),
                        messageOptions: ChatUiStyle.messages(
                          context,
                        ).copyWith(footerBuilder: _followUpFooter),
                      ),
                    ),
                  ),
                  if (_history.isEmpty && !_busy && _error == null)
                    ChatUiStyle.suggestions(
                      context: context,
                      centered: true,
                      chips: _suggestions(),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(context.strings(_error!), textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _send(
                              _failedMessage!,
                              showUser:
                                  widget.showInitialMessage ||
                                  _history.isNotEmpty ||
                                  widget.initialMessage != _failedMessage,
                            ),
                      child: Text(context.strings('tryAgain')),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.strings('aiGeneratedNotice'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ChatUiStyle.composer(
              context: context,
              controller: _input,
              hint: widget.hint,
              sendTooltip: context.strings('sendMessage'),
              enabled:
                  !_busy &&
                  (widget.initialReplyLoader == null || _history.isNotEmpty),
              maxLength: 500,
              onSend: () => _send(_input.text),
              sendKey: widget.sendKey,
            ),
            if (widget.onContinue != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  key: const ValueKey('practice_ai_continue'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onContinue!();
                  },
                  child: Text(context.strings('continue')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
