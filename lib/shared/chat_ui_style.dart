import 'dart:convert';
import 'package:jlpt_practice/core/api/tutor_example.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/vocabulary/example_furigana_text.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';
import 'package:jlpt_practice/core/constants/app_spacing.dart';

/// Chat colors follow the app's active light or dark ColorScheme.
class ChatUiStyle {
  ChatUiStyle._();
  static const _aiTopLeftRadius = 2.0;
  static const _aiOtherRadius = 22.0;
  static const aiBubbleBorderRadius = BorderRadius.only(
    topLeft: Radius.circular(_aiTopLeftRadius),
    topRight: Radius.circular(_aiOtherRadius),
    bottomLeft: Radius.circular(_aiOtherRadius),
    bottomRight: Radius.circular(_aiOtherRadius),
  );

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
    final styleSheet = GptMarkdownStyleSheet(
      inlineCode: InlineCodeStyle(
        fontFamily: 'monospace',
        color: colors.onSurface,
        backgroundColor: colors.surfaceContainerHighest,
      ),
      codeBlock: const CodeBlockStyle(
        borderRadius: Radius.circular(AppSizes.radius8),
      ),
      blockQuote: BlockQuoteStyle(
        barWidth: AppSizes.size3,
        barColor: colors.primary,
        backgroundColor: colors.surfaceContainerHighest,
        textStyle: body,
      ),
      link: LinkStyle(
        color: colors.primary,
        decoration: TextDecoration.underline,
      ),
    );
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
      markdownBuilder: (_, data, _, _) => GptMarkdownTheme(
        gptThemeData: GptMarkdownThemeData(
          brightness: theme.brightness,
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
          styleSheet: styleSheet,
        ),
        child: GptMarkdown(
          data,
          style: body,
          codeBuilder: (context, name, code, closed) {
            if (name == 'jlpt-example' && closed) {
              try {
                final example = TutorExample.fromJson(
                  jsonDecode(code) as Map<String, dynamic>,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExampleFuriganaText(
                        segments: example.segments,
                        style: body,
                        wordTargets: const [],
                        hideReadings: false,
                        alignment: WrapAlignment.start,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        example.translation,
                        style: body.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              } on FormatException {
                return Text(code, style: body);
              } on TypeError {
                return Text(code, style: body);
              }
            }
            return GptMarkdown(
              '```$name\n$code\n```',
              style: body,
              styleSheet: styleSheet,
            );
          },
          inlinePatterns: [
            InlinePattern(
              pattern: RegExp(r'\{([㐀-䶿一-鿿々〆]+)\|([ぁ-ゖー]+)\}'),
              builder: (context, match, style) => WidgetSpan(
                alignment: PlaceholderAlignment.bottom,
                child: ExampleFuriganaText(
                  segments: [FuriganaSegment(match.group(1)!, match.group(2)!)],
                  style: style,
                  wordTargets: const [],
                  hideReadings: false,
                ),
              ),
            ),
          ],
          styleSheet: styleSheet,
          // Links are intentionally inert until chat has an external-link flow.
        ),
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
          borderRadius: aiBubbleBorderRadius,
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
          child: Wrap(
            spacing: AppSpacing.item8,
            runSpacing: AppSpacing.run8,
            children: chips,
          ),
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
      child: Row(spacing: AppSpacing.item8, children: chips),
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
