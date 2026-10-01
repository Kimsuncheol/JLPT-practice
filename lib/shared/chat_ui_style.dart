import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

/// Chat colors follow the app's active light or dark ColorScheme.
class ChatUiStyle {
  ChatUiStyle._();
  static const _aiTopLeftRadius = 2.0;
  static const _aiOtherRadius = 22.0;

  static Widget appBarTitle(BuildContext context, IconData icon, String title) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.size22, color: theme.colorScheme.primary),
        const SizedBox(width: AppSizes.space9),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansKr(
              textStyle:
                  theme.appBarTheme.titleTextStyle ??
                  theme.textTheme.titleLarge,
              color: theme.colorScheme.onSurface,
              fontSize: AppSizes.font21,
              fontWeight: AppFontWeights.bold700,
              letterSpacing: -0.5,
              height: AppSizes.lineHeight1_15,
            ),
          ),
        ),
      ],
    );
  }

  static Widget appBarDivider(BuildContext context) => Divider(
    height: AppSizes.lineHeight0_5,
    thickness: AppSizes.size0_5,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
  );

  static MessageOptions messages(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final body =
        theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface) ??
        TextStyle(color: colors.onSurface);
    return MessageOptions(
      showTime: false,
      showUserName: false,
      bubbleStyle: BubbleStyle(
        userBubbleColor: colors.primaryContainer,
        aiBubbleColor: colors.surfaceContainerHigh,
        aiBubbleTopLeftRadius: _aiTopLeftRadius,
        aiBubbleTopRightRadius: _aiOtherRadius,
        bottomLeftRadius: _aiOtherRadius,
        bottomRightRadius: _aiOtherRadius,
        enableShadow: false,
      ),
      userTextColor: colors.onPrimaryContainer,
      aiTextColor: colors.onSurface,
      markdownStyleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: body,
        pPadding: EdgeInsets.zero,
        strong: body.copyWith(fontWeight: AppFontWeights.boldDefault),
        listBullet: body,
        code: body.copyWith(
          fontFamily: 'monospace',
          backgroundColor: colors.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        h1: body.copyWith(
          fontSize: (body.fontSize ?? 14) + 6,
          fontWeight: AppFontWeights.boldDefault,
        ),
        h2: body.copyWith(
          fontSize: (body.fontSize ?? 14) + 4,
          fontWeight: AppFontWeights.boldDefault,
        ),
        h3: body.copyWith(
          fontSize: (body.fontSize ?? 14) + 2,
          fontWeight: AppFontWeights.boldDefault,
        ),
        blockquote: body,
        blockquoteDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          border: Border(
            left: BorderSide(color: colors.primary, width: AppSizes.size3),
          ),
        ),
        a: body.copyWith(
          color: colors.primary,
          decoration: TextDecoration.underline,
        ),
      ),
      markdownBuilder: (_, data, style, _) => MarkdownBody(
        data: data,
        styleSheet: style,
        shrinkWrap: true,
        softLineBreak: true,
        // Links are intentionally inert until chat has an external-link flow.
      ),
    );
  }

  /// Shows three animated dots in an AI-styled bubble until streaming starts.
  static LoadingConfig loading(BuildContext context, bool isLoading) {
    final colors = Theme.of(context).colorScheme;
    return LoadingConfig(
      isLoading: isLoading,
      loadingIndicator: Container(
        key: const ValueKey('chat_ai_loading_bubble'),
        margin: const EdgeInsets.only(left: AppSizes.size8),
        padding: const EdgeInsets.symmetric(
          vertical: AppSizes.size14,
          horizontal: AppSizes.size16,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(_aiTopLeftRadius),
            topRight: Radius.circular(_aiOtherRadius),
            bottomLeft: Radius.circular(_aiOtherRadius),
            bottomRight: Radius.circular(_aiOtherRadius),
          ),
        ),
        child: _TypingDots(color: colors.onSurfaceVariant),
      ),
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
        borderRadius: BorderRadius.circular(AppSizes.radius18),
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
            fontWeight: AppFontWeights.semiBold,
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
          margin: const EdgeInsets.all(AppSizes.size24),
          padding: const EdgeInsets.all(AppSizes.size16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radius20),
          ),
          child: Wrap(spacing: 8, runSpacing: 8, children: chips),
        ),
      );
    }
    return SingleChildScrollView(
      key: const ValueKey('chat_suggestions_scroll'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.size16,
        vertical: AppSizes.size4,
      ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSizes.size12,
        AppSizes.size4,
        AppSizes.size12,
        AppSizes.size8,
      ),
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
          const SizedBox(width: AppSizes.space8),
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

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: AppSizes.space5),
          Opacity(
            opacity: 0.35 + 0.65 * _pulse((_controller.value - i * 0.2) % 1),
            child: Container(
              width: AppSizes.size8,
              height: AppSizes.size8,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  static double _pulse(double t) => t < 0.5 ? t * 2 : (1 - t) * 2;
}
