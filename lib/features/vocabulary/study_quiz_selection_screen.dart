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
        child: Stack(
          children: [
            Positioned(
              top: 34,
              right: -76,
              child: _BackgroundCircle(
                diameter: 216,
                color: scheme.primary.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              bottom: 24,
              left: -82,
              child: _BackgroundCircle(
                diameter: 188,
                color: scheme.secondary.withValues(alpha: 0.08),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings('chooseQuizGame'),
                          textAlign: TextAlign.left,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _QuizChoiceButton(
                                icon: Icons.quiz_rounded,
                                label: strings('fillInBlankGame'),
                                backgroundColor: scheme.primaryContainer,
                                foregroundColor: scheme.onPrimaryContainer,
                                onPressed: () => context.push(
                                  levelComplete ? '/quiz' : '/quiz/day/$day',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuizChoiceButton(
                                icon: Icons.reorder_rounded,
                                label: strings('sentenceReordering'),
                                backgroundColor: scheme.secondaryContainer,
                                foregroundColor: scheme.onSecondaryContainer,
                                onPressed: () =>
                                    context.push('/study/day/$day/reorder'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizChoiceButton extends StatelessWidget {
  const _QuizChoiceButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.all(8),
        side: BorderSide(color: foregroundColor.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 125;
          final badgeSize = compact ? 38.0 : 56.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: foregroundColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(compact ? 12 : 18),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: compact ? 22 : 30),
              ),
              SizedBox(height: compact ? 6 : 12),
              Flexible(
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 12 : 15,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _BackgroundCircle extends StatelessWidget {
  const _BackgroundCircle({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}
