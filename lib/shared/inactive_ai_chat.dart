import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/shared/chat_ui_style.dart';

/// Retains the AI chat UI while AI features are unavailable.
class InactiveAiChat extends StatefulWidget {
  const InactiveAiChat({
    required this.title,
    required this.icon,
    required this.hint,
    required this.suggestionKeys,
    required this.closeKey,
    this.sendKey,
    super.key,
  });

  final String title;
  final IconData icon;
  final String hint;
  final List<String> suggestionKeys;
  final Key closeKey;
  final Key? sendKey;

  @override
  State<InactiveAiChat> createState() => _InactiveAiChatState();
}

class _InactiveAiChatState extends State<InactiveAiChat> {
  final _messages = ChatMessagesController();
  final _input = TextEditingController();

  @override
  void dispose() {
    _messages.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      scrolledUnderElevation: 0,
      title: ChatUiStyle.appBarTitle(context, widget.icon, widget.title),
      actions: [
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
          ChatUiStyle.appBarDivider(context),
          Expanded(
            child: Stack(
              children: [
                AiChatWidget(
                  currentUser: const ChatUser(id: 'user', firstName: 'You'),
                  aiUser: const ChatUser(id: 'ai', firstName: 'AI'),
                  controller: _messages,
                  onSendMessage: (_) async {},
                  readOnly: true,
                  loadingConfig: ChatUiStyle.loading(context, false),
                  messageOptions: ChatUiStyle.messages(context),
                ),
                ChatUiStyle.suggestions(
                  context: context,
                  centered: true,
                  chips: [
                    for (final key in widget.suggestionKeys)
                      ChatUiStyle.suggestion(context.strings(key), null),
                  ],
                ),
              ],
            ),
          ),
          ChatUiStyle.composer(
            context: context,
            controller: _input,
            hint: widget.hint,
            sendTooltip: context.strings('sendMessage'),
            enabled: false,
            maxLength: 300,
            onSend: () {},
            sendKey: widget.sendKey,
          ),
        ],
      ),
    ),
  );
}
