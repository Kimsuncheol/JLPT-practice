import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

class StudyQuizSelectionScreen extends StatelessWidget {
  const StudyQuizSelectionScreen({
    required this.day,
    this.levelComplete = false,
    super.key,
  });

  final int day;
  final bool levelComplete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: scheme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: scheme.brightness,
          systemStatusBarContrastEnforced: false,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
          ),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(strings('chooseQuizGame')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings('chooseQuizGameSubtitle'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _QuizChoiceButton(
                    icon: Icons.space_bar_rounded,
                    label: strings('fillInBlankGame'),
                    description: strings('fillInBlankGameSubtitle'),
                    onPressed: () => context.push(
                      levelComplete ? '/quiz' : '/quiz/day/$day',
                    ),
                  ),
                  const SizedBox(height: 18),
                  _QuizChoiceButton(
                    icon: Icons.reorder_rounded,
                    label: strings('sentenceReordering'),
                    description: strings('sentenceReorderingSubtitle'),
                    onPressed: () => context.push('/study/day/$day/reorder'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizChoiceButton extends StatelessWidget {
  const _QuizChoiceButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(132),
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : scheme.surface,
          foregroundColor: scheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.55 : 0.8),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_rounded, size: 28),
          ],
        ),
      ),
    );
  }
}
