import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';

/// Chat colors follow the app's active light or dark ColorScheme.
class ChatUiStyle {
  ChatUiStyle._();

  static MessageOptions messages(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MessageOptions(
      showTime: false,
      showUserName: false,
      bubbleStyle: BubbleStyle(
        userBubbleColor: colors.primaryContainer,
        aiBubbleColor: colors.surfaceContainerHigh,
        enableShadow: false,
      ),
      userTextColor: colors.onPrimaryContainer,
      aiTextColor: colors.onSurface,
    );
  }

  static InputDecoration input(BuildContext context, String hint) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.onSurfaceVariant),
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    );
  }

  static Widget suggestion(String label, VoidCallback? onPressed) {
    return Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return ActionChip(
          label: Text(label),
          backgroundColor: colors.secondaryContainer,
          disabledColor: colors.surfaceContainerHigh,
          labelStyle: TextStyle(
            color: onPressed == null
                ? colors.onSurfaceVariant
                : colors.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: colors.outlineVariant),
          onPressed: onPressed,
        );
      },
    );
  }

  static Widget suggestions({
    required BuildContext context,
    required List<Widget> chips,
    required bool centered,
  }) {
    if (centered) {
      return Center(
        child: Container(
          key: const ValueKey('chat_suggestions_container'),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Wrap(spacing: 8, runSpacing: 8, children: chips),
        ),
      );
    }
    return SingleChildScrollView(
      key: const ValueKey('chat_suggestions_scroll'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(spacing: 8, children: chips),
    );
  }

  static Widget composer({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    required String sendTooltip,
    required bool enabled,
    required int maxLength,
    required VoidCallback onSend,
    Key? sendKey,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLength: maxLength,
              maxLines: 4,
              minLines: 1,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              decoration: input(context, hint),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: sendKey,
            tooltip: sendTooltip,
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
