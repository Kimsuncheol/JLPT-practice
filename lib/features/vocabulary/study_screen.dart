import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/core/utils/immersive_study_mode.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/vocabulary/audible_speech.dart';
import 'package:jlpt_practice/features/vocabulary/cover_masking.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';
import 'package:jlpt_practice/features/vocabulary/example_furigana_text.dart';
import 'package:jlpt_practice/features/vocabulary/short_quiz.dart';
import 'package:jlpt_practice/features/vocabulary/short_quiz_game.dart';
import 'package:jlpt_practice/features/vocabulary/masked_translation.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_colors.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({required this.day, this.startOver = false, super.key});

  final int day;
  final bool startOver;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen>
    with ImmersiveStudyMode<StudyScreen> {
  static const _dialogBarrierColor = AppPalette.black54;

  int _index = 0;
  bool _shortQuizEnabled = false;
  bool _continuousShortQuizEnabled = false;
  int _shortQuizRun = 0;
  Timer? _shortQuizFeedbackTimer;
  static const _shortQuizFeedbackDuration = Duration(milliseconds: 1500);
  final Map<String, ShortQuiz?> _shortQuizzes = {};
  final Map<String, String?> _shortQuizSelections = {};
  final Map<String, _CardVisibility> _cardVisibility = {};
  PageController? _pageController;
  TtsService? _ttsService;
  bool _resumeDecisionPending = false;
  bool _resumeDialogVisible = false;
  bool _leaveDialogVisible = false;
  bool _suppressAutoAudio = false;
  int _pageChangeRequest = 0;
  int _readingsRequest = 0;
  static const _readingGap = Duration(milliseconds: 500);

  @override
  void reassemble() {
    super.reassemble();
    _shortQuizFeedbackTimer?.cancel();
    // Hot reload preserves cached model instances without running their new
    // constructors. Rebuild quizzes so newly added fields are initialized.
    _shortQuizEnabled = false;
    _continuousShortQuizEnabled = false;
    _shortQuizzes.clear();
    _shortQuizSelections.clear();
  }

  @override
  void dispose() {
    _shortQuizFeedbackTimer?.cancel();
    _pageController?.dispose();
    _readingsRequest++;
    if (_ttsService != null) unawaited(_ttsService!.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(appControllerProvider);
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final systemBarColor = _resumeDialogVisible || _leaveDialogVisible
        ? Color.alphaBlend(_dialogBarrierColor, scaffoldBackgroundColor)
        : scaffoldBackgroundColor;
    return wrapImmersive(
      asyncState.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) =>
            Scaffold(body: Center(child: Text(error.toString()))),
        data: (state) => _buildStudyScreen(context, state),
      ),
      systemBarColor: systemBarColor,
    );
  }

  Widget _buildStudyScreen(BuildContext context, AppState state) {
    final words = StudyBatches.wordsForDay(
      state.selectedVocabulary,
      day: widget.day,
      dailyGoal: state.dailyGoal,
    );
    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.strings('noResults'))),
      );
    }
    _initializePage(words, state);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _confirmLeave,
            icon: const Icon(Icons.close_rounded),
          ),
          title: Text(
            '${context.strings('day')} ${widget.day}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          centerTitle: false,
          titleSpacing: AppSizes.size0,
          actions: [
            IconButton(
              onPressed: () => context.push('/settings/learning'),
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: const ValueKey('study-word-pages'),
                controller: _pageController,
                itemCount: words.length + 1,
                onPageChanged: (index) => unawaited(
                  _handlePageChanged(index: index, words: words, state: state),
                ),
                itemBuilder: (context, index) {
                  if (index == words.length) {
                    return const SizedBox.shrink();
                  }
                  final word = words[index];
                  final visibility = _visibilityFor(word, state);
                  final quiz = _shortQuizEnabled ? _quizFor(word, state) : null;
                  final showFurigana = visibility.showFurigana;
                  final hideWord =
                      quiz != null ||
                      visibility.hideWord ||
                      (!showFurigana && word.reading == word.word);
                  final meaningsHidden = visibility.hideMeanings;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSizes.size20,
                      AppSizes.size8,
                      AppSizes.size20,
                      quiz == null ? AppSizes.size14 : 0,
                    ),
                    child: _StudyCard(
                      key: ValueKey('${word.id}-$_shortQuizRun'),
                      vocabulary: word,
                      quiz: quiz,
                      quizSelection: _shortQuizSelections[word.id],
                      onQuizSelected: (answer) =>
                          _handleQuizSelected(word, answer),
                      language: state.meaningLanguage,
                      showFurigana: showFurigana,
                      hideWord: hideWord,
                      hideMeaning: meaningsHidden,
                      maskMeaningInTranslation: meaningsHidden,
                      onSpeakWord: () =>
                          _speakIfAudible(word.speechText, word: word),
                      onSpeakExample: () =>
                          _speakIfAudible(word.example.speechText),
                    ),
                  );
                },
              ),
            ),
            Padding(
              key: const ValueKey('study-hide-container'),
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.size20),
              child: SizedBox(
                height:
                    94 + (MediaQuery.textScalerOf(context).scale(11) - 11) * 3,
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        key: const ValueKey('study-hide-pages'),
                        children: [
                          _actionPage([
                            ..._manualActions(state, words[_index]),
                            _CardAction(
                              icon: _continuousShortQuizEnabled
                                  ? Icons.all_inclusive
                                  : _shortQuizEnabled
                                  ? Icons.quiz
                                  : Icons.quiz_outlined,
                              label: context.strings('shortQuiz'),
                              onTap:
                                  !_shortQuizEnabled &&
                                      _quizFor(words[_index], state) == null
                                  ? null
                                  : () {
                                      final enabled =
                                          _continuousShortQuizEnabled ||
                                          !_shortQuizEnabled;
                                      _continuousShortQuizEnabled = false;
                                      _setShortQuizEnabled(enabled);
                                    },
                              onLongPress: () {
                                _continuousShortQuizEnabled =
                                    !_continuousShortQuizEnabled;
                                _setShortQuizEnabled(
                                  _continuousShortQuizEnabled,
                                );
                              },
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.size20,
                  AppSizes.size30,
                  AppSizes.size20,
                  AppSizes.size20,
                ),
                child: Text(
                  '${_index + 1} / ${words.length}',
                  style: const TextStyle(fontWeight: AppFontWeights.bold700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLeave() async {
    if (_leaveDialogVisible || _resumeDialogVisible) {
      return;
    }
    final dimmedBackground = Color.alphaBlend(
      _dialogBarrierColor,
      Theme.of(context).scaffoldBackgroundColor,
    );
    setImmersiveOuterBackgroundColor(dimmedBackground);
    setState(() => _leaveDialogVisible = true);
    bool shouldLeave = false;
    try {
      final dialogResult = showDialog<bool>(
        context: context,
        barrierColor: _dialogBarrierColor,
        builder: (dialogContext) => wrapImmersiveSystemBarGesture(
          AlertDialog(
            title: Text(dialogContext.strings('leaveStudyTitle')),
            content: Text(dialogContext.strings('leaveStudyBody')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogContext.strings('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(dialogContext.strings('leave')),
              ),
            ],
          ),
        ),
      );
      _applySystemBarColorAfterFrame(modalVisible: true);
      shouldLeave = await dialogResult ?? false;
    } finally {
      if (mounted) {
        setImmersiveOuterBackgroundColor(null);
        setState(() => _leaveDialogVisible = false);
        reassertImmersiveMode();
        _applySystemBarColorAfterFrame(modalVisible: false);
      }
    }
    if (mounted && shouldLeave) context.pop();
  }

  Widget _actionPage(List<Widget> actions) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (final action in actions) Flexible(child: action)],
  );

  _CardVisibility _visibilityFor(Vocabulary word, AppState state) =>
      _cardVisibility.putIfAbsent(
        word.id,
        () => _CardVisibility(
          showFurigana: state.showFurigana,
          hideWord: state.hideWord,
          hideMeanings: state.hideMeanings,
        ),
      );

  ShortQuiz? _quizFor(Vocabulary word, AppState state) =>
      _shortQuizzes.putIfAbsent(
        word.id,
        () => buildShortQuiz(word, state.selectedVocabulary),
      );

  void _setShortQuizEnabled(bool enabled) {
    _shortQuizFeedbackTimer?.cancel();
    setState(() {
      _shortQuizEnabled = enabled;
      _shortQuizSelections.clear();
      _shortQuizRun++;
    });
    _readingsRequest++;
    if (_ttsService != null) unawaited(_ttsService!.stop());
  }

  void _handleQuizSelected(Vocabulary word, String? answer) {
    _shortQuizFeedbackTimer?.cancel();
    setState(() => _shortQuizSelections[word.id] = answer);
    if (answer == null) return;
    _shortQuizFeedbackTimer = Timer(_shortQuizFeedbackDuration, () {
      if (!mounted) return;
      setState(() {
        _shortQuizEnabled = false;
        _shortQuizSelections.clear();
      });
    });
  }

  List<Widget> _manualActions(AppState state, Vocabulary word) {
    final visibility = _visibilityFor(word, state);
    final wordIsReading = word.word == word.reading;
    final wordAndReadingHidden =
        visibility.hideWord || !visibility.showFurigana;
    return [
      if (wordIsReading)
        _CardAction(
          icon: wordAndReadingHidden
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
          label: context.strings(
            wordAndReadingHidden ? 'showWordAndReading' : 'hideWordAndReading',
          ),
          onTap: () => setState(() {
            final current = _cardVisibility[word.id]!;
            final hidden = current.hideWord || !current.showFurigana;
            _cardVisibility[word.id] = current.copyWith(
              showFurigana: hidden,
              hideWord: !hidden,
            );
          }),
        )
      else ...[
        _CardAction(
          icon: visibility.showFurigana
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          label: context.strings(
            visibility.showFurigana ? 'hideReading' : 'showReading',
          ),
          onTap: () => setState(() {
            final current = _cardVisibility[word.id]!;
            _cardVisibility[word.id] = current.copyWith(
              showFurigana: !current.showFurigana,
            );
          }),
        ),
        _CardAction(
          icon: visibility.hideWord
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
          label: context.strings(visibility.hideWord ? 'showWord' : 'hideWord'),
          onTap: () => setState(() {
            final current = _cardVisibility[word.id]!;
            _cardVisibility[word.id] = current.copyWith(
              hideWord: !current.hideWord,
            );
          }),
        ),
      ],
      _CardAction(
        icon: visibility.hideMeanings
            ? Icons.visibility_rounded
            : Icons.visibility_off_rounded,
        label: context.strings(
          visibility.hideMeanings ? 'showMeanings' : 'hideMeanings',
        ),
        onTap: () => setState(() {
          final current = _cardVisibility[word.id]!;
          _cardVisibility[word.id] = current.copyWith(
            hideMeanings: !current.hideMeanings,
          );
        }),
      ),
    ];
  }

  void _initializePage(List<Vocabulary> words, AppState state) {
    if (_pageController != null) return;
    final session = state.studySessions[state.selectedLevel];
    final canResume =
        !widget.startOver &&
        session != null &&
        session.day == widget.day &&
        session.isCompatible(
          level: state.selectedLevel,
          dailyGoal: state.dailyGoal,
        );
    _pageController = PageController();
    _resumeDecisionPending = canResume;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (canResume) {
        unawaited(_confirmResume(session, words));
      } else {
        unawaited(_savePosition(state, words.first, 0));
        _autoPlayFirstWord(words.first);
      }
    });
  }

  Future<void> _confirmResume(
    StudySession session,
    List<Vocabulary> words,
  ) async {
    final resumeIndex = session.resolveIndex(
      words.map((word) => word.id).toList(),
    );
    setImmersiveOuterBackgroundColor(
      Color.alphaBlend(
        _dialogBarrierColor,
        Theme.of(context).scaffoldBackgroundColor,
      ),
    );
    setState(() => _resumeDialogVisible = true);
    bool? shouldResume;
    try {
      final dialogResult = showDialog<bool>(
        context: context,
        barrierColor: _dialogBarrierColor,
        barrierDismissible: false,
        builder: (dialogContext) => wrapImmersiveSystemBarGesture(
          PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(dialogContext.strings('resumeConfirmTitle')),
              content: Text(
                '${dialogContext.strings('day')} ${session.day} · ${resumeIndex + 1}/${words.length}\n${dialogContext.strings('resumeConfirmBody')}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(dialogContext.strings('chooseAnotherDay')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(dialogContext.strings('continue')),
                ),
              ],
            ),
          ),
        ),
      );
      _applySystemBarColorAfterFrame(modalVisible: true);
      shouldResume = await dialogResult;
    } finally {
      if (mounted) {
        setImmersiveOuterBackgroundColor(null);
        setState(() => _resumeDialogVisible = false);
        reassertImmersiveMode();
        _applySystemBarColorAfterFrame(modalVisible: false);
      }
    }
    if (!mounted || shouldResume == null) return;
    _resumeDecisionPending = false;
    if (!shouldResume) {
      context.pushReplacement('/study');
      return;
    }

    if (resumeIndex == 0) {
      // Resuming on the first word never changes the page, so the page-change
      // handler cannot play it.
      _autoPlayFirstWord(words.first);
      return;
    }
    _suppressAutoAudio = true;
    _pageController!.jumpToPage(resumeIndex);
  }

  void _applySystemBarColorAfterFrame({required bool modalVisible}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          (_resumeDialogVisible || _leaveDialogVisible) != modalVisible) {
        return;
      }
      final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;
      final color = modalVisible
          ? Color.alphaBlend(_dialogBarrierColor, scaffoldBackgroundColor)
          : scaffoldBackgroundColor;
      applyImmersiveSystemBarColor(color);
    });
  }

  Future<void> _savePosition(AppState state, Vocabulary word, int index) {
    return ref
        .read(appControllerProvider.notifier)
        .saveStudySession(
          StudySession(
            level: state.selectedLevel,
            day: widget.day,
            wordId: word.id,
            indexFallback: index,
            dailyGoal: state.dailyGoal,
            updatedAt: DateTime.now(),
          ),
        );
  }

  /// The first word is on screen from the start, so no page change fires to
  /// trigger automatic pronunciation for it.
  void _autoPlayFirstWord(Vocabulary word) {
    if (!mounted) return;
    if (ref.read(appControllerProvider).value?.autoPlayAudio ?? false) {
      _speakWord(word);
    }
  }

  void _speak(String text) {
    _ttsService ??= ref.read(ttsServiceProvider);
    _readingsRequest++;
    unawaited(_ttsService!.speak(text));
  }

  /// Words with several readings (`なん/なに`) are spoken one reading at a
  /// time, [_readingGap] apart, so each pronunciation is heard on its own.
  void _speakReadings(List<String> readings) {
    final service = ref.read(ttsServiceProvider);
    _ttsService ??= service;
    final request = ++_readingsRequest;
    unawaited(() async {
      for (var i = 0; i < readings.length; i++) {
        if (request != _readingsRequest || !mounted) return;
        if (i > 0) {
          await Future<void>.delayed(_readingGap);
          if (request != _readingsRequest || !mounted) return;
        }
        await service.speak(readings[i]);
      }
    }());
  }

  void _speakWord(Vocabulary word) {
    final readings = splitReadings(word.speechText);
    if (readings.length > 1) {
      _speakReadings(readings);
    } else {
      _speak(word.speechText);
    }
  }

  Future<void> _speakIfAudible(String text, {Vocabulary? word}) async {
    final settings = ref.read(appControllerProvider).value;
    if (!await confirmSpeechAudible(context, settings) || !mounted) return;
    final readings = word == null ? const <String>[] : splitReadings(text);
    if (readings.length > 1) {
      _speakReadings(readings);
    } else {
      _speak(text);
    }
  }

  Future<void> _handlePageChanged({
    required int index,
    required List<Vocabulary> words,
    required AppState state,
  }) async {
    final request = ++_pageChangeRequest;
    if (index != _index) {
      _shortQuizFeedbackTimer?.cancel();
      setState(() {
        _shortQuizEnabled = _continuousShortQuizEnabled;
        _shortQuizSelections.clear();
        _shortQuizRun++;
      });
    }
    if (_ttsService != null) await _ttsService!.stop();
    if (!mounted || request != _pageChangeRequest) return;

    if (index == words.length) {
      await _finishStudying();
      return;
    }
    setState(() => _index = index);
    if (_resumeDecisionPending) return;
    unawaited(_savePosition(state, words[index], index));
    if (state.autoPlayAudio && !_suppressAutoAudio && !_shortQuizEnabled) {
      _speakWord(words[index]);
    }
    _suppressAutoAudio = false;
  }

  Future<void> _finishStudying() async {
    if (_ttsService != null) {
      await _ttsService!.stop();
      _ttsService = null;
    }
    if (mounted) {
      context.pushReplacement('/study/day/${widget.day}/finish');
    }
  }
}

class _CardVisibility {
  const _CardVisibility({
    required this.showFurigana,
    required this.hideWord,
    required this.hideMeanings,
  });

  final bool showFurigana;
  final bool hideWord;
  final bool hideMeanings;

  _CardVisibility copyWith({
    bool? showFurigana,
    bool? hideWord,
    bool? hideMeanings,
  }) => _CardVisibility(
    showFurigana: showFurigana ?? this.showFurigana,
    hideWord: hideWord ?? this.hideWord,
    hideMeanings: hideMeanings ?? this.hideMeanings,
  );
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({
    required this.vocabulary,
    this.quiz,
    this.quizSelection,
    this.onQuizSelected,
    required this.language,
    required this.showFurigana,
    required this.hideWord,
    required this.hideMeaning,
    required this.maskMeaningInTranslation,
    required this.onSpeakWord,
    required this.onSpeakExample,
    super.key,
  });

  final Vocabulary vocabulary;
  final ShortQuiz? quiz;
  final String? quizSelection;
  final ValueChanged<String?>? onQuizSelected;
  final String language;
  final bool showFurigana;
  final bool hideWord;
  final bool hideMeaning;
  final bool maskMeaningInTranslation;
  final VoidCallback onSpeakWord;
  final VoidCallback onSpeakExample;

  @override
  Widget build(BuildContext context) {
    if (quiz != null) return _buildShortQuizCard(context);
    return _centeredScrollable(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.size24,
        AppSizes.size26,
        AppSizes.size24,
        AppSizes.size24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReading(context),
          const SizedBox(height: AppSizes.space4),
          _buildRomaji(context),
          const SizedBox(height: AppSizes.space6),
          _buildWord(context),
          const SizedBox(height: AppSizes.space10),
          const SizedBox(height: AppSizes.space18),
          _buildMeaning(context),
          if (vocabulary.hasExample) ...[
            const SizedBox(height: AppSizes.space34),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.size20),
              child: _buildExample(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShortQuizCard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          // Anchor the heading to the viewport, independently of answers,
          // wrapped option rows and scrolling in the example.
          SizedBox(height: constraints.maxHeight * 0.22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.size24),
            child: _buildMeaning(context),
          ),
          const SizedBox(height: AppSizes.space32),
          Expanded(
            child: LayoutBuilder(
              builder: (context, remaining) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: remaining.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.size24,
                          ),
                          child: _buildExample(context),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centeredScrollable({
    required EdgeInsets padding,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - padding.vertical),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildReading(BuildContext context) {
    final hasReading = vocabulary.reading != vocabulary.word;
    if (!hasReading) return const SizedBox.shrink();
    final titleLarge = Theme.of(context).textTheme.titleLarge;
    return _speechTarget(
      onTap: onSpeakWord,
      child: _coveredReadingText(
        breakLongSlashSeparatedLabel(vocabulary.reading),
        style: titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildRomaji(BuildContext context) {
    if (vocabulary.romaji.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return _speechTarget(
      onTap: onSpeakWord,
      child: _coveredReadingText(
        breakLongSlashSeparatedLabel(vocabulary.romaji),
        style: style,
      ),
    );
  }

  Widget _coveredReadingText(String text, {required TextStyle? style}) {
    final hidden = !showFurigana || quiz != null;
    return Stack(
      children: [
        Text.rich(
          TextSpan(text: text, semanticsLabel: hidden ? '' : null),
          textAlign: TextAlign.center,
          style: hidden
              ? (style ?? const TextStyle()).copyWith(color: Colors.transparent)
              : style,
        ),
        if (hidden)
          const Positioned.fill(child: CoverTape(width: 0, height: 0)),
      ],
    );
  }

  Widget _buildWord(BuildContext context) {
    final displayWord = breakLongSlashSeparatedLabel(vocabulary.word);
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        onTap: onSpeakWord,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.size12,
            vertical: AppSizes.size4,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Stack(
              key: const ValueKey('study-word-area'),
              children: [
                Text.rich(
                  TextSpan(
                    text: displayWord,
                    semanticsLabel: hideWord ? '' : null,
                  ),
                  maxLines: displayWord.contains('\n') ? null : 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: hideWord ? Colors.transparent : null,
                    fontSize: AppSizes.font56,
                    height: AppSizes.lineHeight1_15,
                    fontWeight: AppFontWeights.extraBold,
                  ),
                ),
                if (hideWord)
                  const Positioned.fill(
                    child: CoverTape(width: 0, height: 0, tilt: -0.02),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _speechTarget({required VoidCallback onTap, required Widget child}) =>
      Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.size8,
              vertical: AppSizes.size4,
            ),
            child: child,
          ),
        ),
      );

  Widget _buildMeaning(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium;
    final meaning = vocabulary.meaning(language);
    return Container(
      key: const ValueKey('study-meanings-area'),
      color: Colors.transparent,
      child: Visibility(
        visible: !hideMeaning,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: Text(meaning, textAlign: TextAlign.center, style: style),
      ),
    );
  }

  Widget _buildExample(BuildContext context) {
    final sentenceStyle = Theme.of(context).textTheme.titleLarge;
    final translationStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (quiz != null)
          ShortQuizGame(
            key: ValueKey('short-quiz-${vocabulary.id}'),
            quiz: quiz!,
            initialSelection: quizSelection,
            onSelected: onQuizSelected,
            showFurigana: showFurigana,
            translation: _buildTranslation(context, translationStyle),
          )
        else
          Semantics(
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.radius12),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              onTap: onSpeakExample,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.size8,
                  vertical: AppSizes.size4,
                ),
                child: ExampleFuriganaText(
                  key: const ValueKey('example-furigana'),
                  segments: vocabulary.example.sentenceSegments,
                  style:
                      sentenceStyle ??
                      const TextStyle(fontSize: AppSizes.font22),
                  wordTargets: hideWord
                      ? wordMaskTargets(vocabulary.word)
                      : const [],
                  hideReadings: !showFurigana,
                  maintainReadingLayout: true,
                  alignment: WrapAlignment.start,
                ),
              ),
            ),
          ),
        if (quiz == null) ...[
          const SizedBox(height: AppSizes.space4),
          _buildTranslation(context, translationStyle),
        ],
      ],
    );
  }

  Widget _buildTranslation(BuildContext context, TextStyle style) {
    final translation = _withRolePlayLineBreaks(
      vocabulary.example.translation(language),
    );
    final highlightStyle = quiz == null
        ? null
        : const TextStyle(fontWeight: AppFontWeights.bold700);
    // Korean meanings are inflected inside Korean translations, so they are
    // matched by lemma; other languages keep the plain substring mask.
    final koreanMeanings = vocabulary.meanings['ko'];
    if (language == 'ko' && koreanMeanings != null) {
      return MaskedTranslation(
        translation: translation,
        meanings: koreanMeanings,
        hideMeanings: quiz == null && maskMeaningInTranslation,
        highlightStyle: highlightStyle,
        style: style,
        glyphWidth: 0.55,
        textAlign: TextAlign.start,
      );
    }
    return _maskedText(
      translation,
      style: style,
      targets: quiz != null || maskMeaningInTranslation
          ? meaningMaskTargets(
              vocabulary.meanings[language] ??
                  vocabulary.meanings['en'] ??
                  const [],
            )
          : const [],
      glyphWidth: 0.55,
      highlightStyle: highlightStyle,
    );
  }

  /// Renders [text] from the leading edge, laying tape over matching runs.
  Widget _maskedText(
    String text, {
    required TextStyle? style,
    required List<String> targets,
    required double glyphWidth,
    TextStyle? highlightStyle,
  }) {
    if (targets.isEmpty) {
      return Text(text, textAlign: TextAlign.start, style: style);
    }
    return MaskedSegmentsText(
      segments: maskSegments(text, targets),
      style: style,
      glyphWidth: glyphWidth,
      highlightStyle: highlightStyle,
      textAlign: TextAlign.start,
    );
  }
}

String _withRolePlayLineBreaks(String text) => text.replaceAllMapped(
  RegExp(r'([.!?。！？])\s*(?=[A-Za-z][A-Za-z0-9]{0,2}\s*[：:])'),
  (match) => '${match.group(1)}\n',
);

/// Keeps short alternatives on one line and gives long slash-separated words
/// a predictable break point instead of shrinking the whole label.
String breakLongSlashSeparatedLabel(String text) {
  if (!text.contains('/') || text.replaceAll(RegExp(r'\s'), '').length < 12) {
    return text;
  }
  return text.replaceAllMapped(RegExp(r'\s*/\s*'), (_) => ' /\n');
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });
  final IconData icon;
  final String label;

  /// With no callbacks the action is inert and semi-transparent.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null && onLongPress == null ? 0.38 : 1,
    child: RawGestureDetector(
      gestures: {
        if (onLongPress != null)
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: const Duration(seconds: 1),
                ),
                (recognizer) => recognizer.onLongPress = onLongPress,
              ),
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSizes.size10,
            horizontal: AppSizes.size12,
          ),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: AppSizes.space6),
              Text(
                label.replaceFirst(' ', '\n'),
                semanticsLabel: label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
