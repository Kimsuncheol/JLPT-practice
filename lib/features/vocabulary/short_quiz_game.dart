import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/constants/app_spacing.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/vocabulary/cover_masking.dart';
import 'package:jlpt_practice/features/vocabulary/example_furigana_text.dart';
import 'package:jlpt_practice/features/vocabulary/short_quiz.dart';

class ShortQuizGame extends StatefulWidget {
  const ShortQuizGame({
    required this.quiz,
    required this.showFurigana,
    this.initialSelection,
    this.onSelected,
    this.translation,
    super.key,
  });

  final String? initialSelection;
  final ValueChanged<String?>? onSelected;
  final ShortQuiz quiz;
  final bool showFurigana;
  final Widget? translation;

  @override
  State<ShortQuizGame> createState() => _ShortQuizGameState();
}

class _ShortQuizGameState extends State<ShortQuizGame> {
  final _blankKey = GlobalKey();
  final _optionKeys = <String, GlobalKey>{};
  String? _selected;
  OverlayEntry? _flight;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  @override
  void dispose() {
    _flight?.remove();
    _flight?.dispose();
    super.dispose();
  }

  void _select(String option) {
    if (_selected != null) return;
    final source = _optionKeys[option]?.currentContext?.findRenderObject();
    final destination = _blankKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject();
    Rect? from;
    Rect? to;
    if (source is RenderBox &&
        destination is RenderBox &&
        overlayBox is RenderBox) {
      from =
          source.localToGlobal(Offset.zero, ancestor: overlayBox) & source.size;
      to =
          destination.localToGlobal(Offset.zero, ancestor: overlayBox) &
          destination.size;
    }
    // Grade on the tap itself; the travel animation never delays feedback.
    final correct = widget.quiz.grade(option);
    setState(() {
      _selected = option;
      _moving =
          from != null &&
          to != null &&
          !MediaQuery.disableAnimationsOf(context);
    });
    widget.onSelected?.call(option);
    if (!_moving) return;
    final begin = from!;
    final colors = Theme.of(context).colorScheme;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Feedback can change the card's height. Aim at the blank after that
      // layout, so the moving chip lands at its displayed position.
      final target = _blankKey.currentContext?.findRenderObject();
      if (target is! RenderBox || overlayBox is! RenderBox) {
        setState(() => _moving = false);
        return;
      }
      final targetRect =
          target.localToGlobal(Offset.zero, ancestor: overlayBox) & target.size;
      final end = Rect.fromCenter(
        center: targetRect.center,
        width: begin.width,
        height: begin.height,
      );
      _flight = OverlayEntry(
        builder: (_) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          onEnd: () {
            _flight?.remove();
            _flight?.dispose();
            _flight = null;
            if (mounted) setState(() => _moving = false);
          },
          builder: (_, progress, _) {
            final rect = Rect.lerp(begin, end, progress)!;
            return Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: Material(
                  color: Colors.transparent,
                  child: Chip(
                    label: _optionLabel(context, option),
                    backgroundColor: correct
                        ? colors.primaryContainer
                        : colors.errorContainer,
                  ),
                ),
              ),
            );
          },
        ),
      );
      overlay.insert(_flight!);
    });
  }

  Widget _optionLabel(
    BuildContext context,
    String option, {
    Key? wordKey,
    TextStyle? style,
  }) {
    final reading = widget.quiz.optionReadings[option] ?? '';
    final readingStyle = TextStyle(
      fontSize: 11,
      height: 1.2,
      color: Theme.of(context).colorScheme.primary,
    );
    final word = Text(
      option,
      key: wordKey,
      textAlign: TextAlign.center,
      style: style,
    );
    if (reading.isEmpty) {
      final readingLine = TextPainter(
        text: TextSpan(text: ' ', style: readingStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final padding = readingLine.height / 2;
      readingLine.dispose();
      return Padding(
        padding: EdgeInsets.symmetric(vertical: padding),
        child: word,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          reading,
          key: ValueKey('short-quiz-reading-$option'),
          textAlign: TextAlign.center,
          style: readingStyle,
        ),
        word,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.quiz;
    final colors = Theme.of(context).colorScheme;
    final correct = _selected != null && quiz.grade(_selected!);
    final blank = Container(
      key: _blankKey,
      constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _selected == null
            ? colors.surfaceContainerHighest
            : correct
            ? colors.primaryContainer
            : colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selected == null
              ? colors.outline
              : correct
              ? colors.primary
              : colors.error,
        ),
      ),
      child: Opacity(
        opacity: _moving ? 0 : 1,
        child: _optionLabel(
          context,
          _selected ?? '',
          wordKey: const ValueKey('short-quiz-blank'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExampleFuriganaText(
          segments: quiz.segments,
          style:
              Theme.of(context).textTheme.titleLarge ??
              const TextStyle(fontSize: 22),
          wordTargets: wordMaskTargets(quiz.entry.word),
          hideReadings: !widget.showFurigana,
          alignment: WrapAlignment.start,
          replacements: {ShortQuiz.placeholder: blank},
          replacementLabels: {ShortQuiz.placeholder: _selected ?? '…'},
          hideCoveredReadings: true,
        ),
        if (widget.translation != null) ...[
          const SizedBox(height: 8),
          Center(child: widget.translation!),
        ],
        const SizedBox(height: AppSpacing.shortQuizTranslationOptions),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in quiz.options)
              if (option != _selected)
                ActionChip(
                  key: _optionKeys.putIfAbsent(option, GlobalKey.new),
                  label: _optionLabel(context, option),
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.pressed)) {
                      return colors.primaryContainer;
                    }
                    return colors.surfaceContainerLow;
                  }),
                  onPressed: _selected == null ? () => _select(option) : null,
                ),
          ],
        ),
      ],
    );
  }
}

class ShortQuizFeedback extends StatelessWidget {
  const ShortQuizFeedback({
    required this.quiz,
    required this.selection,
    super.key,
  });

  final ShortQuiz quiz;
  final String selection;

  @override
  Widget build(BuildContext context) {
    final correct = quiz.grade(selection);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey('short-quiz-feedback'),
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: correct ? colors.primary : colors.error,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              correct
                  ? context.strings('correct')
                  : '${context.strings('incorrect')} · ${context.strings('answer')}: ${quiz.answer}',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
