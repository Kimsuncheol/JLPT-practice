import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/core/services/volume_service.dart';
import 'package:jlpt_practice/core/utils/immersive_study_mode.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/vocabulary/cover_masking.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';
import 'package:jlpt_practice/features/vocabulary/masked_translation.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({required this.day, super.key});

  final int day;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen>
    with ImmersiveStudyMode<StudyScreen> {
  static const _resumeDialogBarrierColor = Colors.black54;

  int _index = 0;
  final Map<String, _CardVisibility> _cardVisibility = {};
  PageController? _pageController;
  final PageController _actionPageController = PageController(
    initialPage: 10000,
  );
  int _currentActionPage = 10000;
  TtsService? _ttsService;
  bool _resumeDecisionPending = false;
  bool _resumeDialogVisible = false;
  bool _suppressAutoAudio = false;
  int _pageChangeRequest = 0;
  int _readingsRequest = 0;
  static const _readingGap = Duration(milliseconds: 500);

  /// Auto review: how many of the order's elements are revealed on the
  /// current card, the timer that reveals the next one, and the pause switch.
  Timer? _autoTimer;
  int _autoRevealed = 1;
  bool _autoPaused = false;

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController?.dispose();
    _actionPageController.dispose();
    _readingsRequest++;
    if (_ttsService != null) unawaited(_ttsService!.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(appControllerProvider);
    ref.listen(
      appControllerProvider.select(
        (state) => (
          state.value == null ? null : _autoReviewActive(state.value!),
          state.value?.autoReviewOrder,
          state.value?.autoReviewSeconds,
        ),
      ),
      (_, _) => _restartAutoReview(),
    );
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final systemBarColor = _resumeDialogVisible
        ? Color.alphaBlend(_resumeDialogBarrierColor, scaffoldBackgroundColor)
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.close_rounded),
        ),
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
              controller: _pageController,
              itemCount: words.length + 1,
              onPageChanged: (index) => unawaited(
                _handlePageChanged(index: index, words: words, state: state),
              ),
              itemBuilder: (context, index) {
                if (index == words.length) return const SizedBox.shrink();
                final word = words[index];
                final visibility = _visibilityFor(word, state);
                final revealed = _autoReviewActive(state)
                    ? state.autoReviewOrder.elements
                          .take(index == _index ? _autoRevealed : 1)
                          .toSet()
                    : null;
                final showFurigana = revealed == null
                    ? visibility.showFurigana
                    : revealed.contains(ReviewElement.reading);
                final hideWord = revealed == null
                    ? visibility.hideWord ||
                          (!showFurigana && word.reading == word.word)
                    : !revealed.contains(ReviewElement.word);
                final meaningsHidden = revealed == null
                    ? visibility.hideMeanings
                    : !revealed.contains(ReviewElement.meanings);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: _StudyCard(
                    vocabulary: word,
                    language: state.meaningLanguage,
                    showFurigana: showFurigana,
                    hideWord: hideWord,
                    hideMeaning: meaningsHidden,
                    maskMeaningInTranslation: meaningsHidden,
                    onSpeakWord: () =>
                        _speakIfAudible(word.reading, word: word),
                    onSpeakExample: () =>
                        _speakIfAudible(word.example.sentence),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 82,
              child: _buildActionArea(state, words[_index]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
              child: Text(
                '${_index + 1} / ${words.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Switches auto review on or off. Only offered on a finished day.
  Widget _autoReviewTab(AppState state) => _CardAction(
    icon: _autoReviewActive(state)
        ? Icons.play_circle_rounded
        : Icons.play_circle_outline_rounded,
    label: context.strings('autoReview'),
    onTap: () => unawaited(
      ref
          .read(appControllerProvider.notifier)
          .setAutoReviewEnabled(!state.autoReviewEnabled),
    ),
  );

  Widget _actionPage(List<Widget> actions) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (final action in actions) Flexible(child: action)],
  );

  Widget _buildActionArea(AppState state, Vocabulary word) {
    // The combined word/reading control leaves room for Auto review on the
    // primary page, so a duplicate second page would serve no purpose. With
    // auto review unavailable there is nothing for a second page to show.
    if (word.word == word.reading || !_dayFinished(state)) {
      return _primaryActionPage(state, word);
    }
    return PageView.builder(
      key: const ValueKey('study-action-carousel'),
      controller: _actionPageController,
      onPageChanged: (page) => _currentActionPage = page,
      itemBuilder: (context, page) => page.isEven
          ? _primaryActionPage(state, word)
          : _actionPage([_autoReviewTab(state)]),
    );
  }

  Widget _primaryActionPage(AppState state, Vocabulary word) {
    if (_autoReviewActive(state)) {
      return _actionPage([
        _CardAction(
          icon: _autoPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          label: context.strings(
            _autoPaused ? 'resumeAutoReview' : 'pauseAutoReview',
          ),
          onTap: _toggleAutoReviewPause,
        ),
      ]);
    }

    final actions = _manualActions(state, word);
    if (word.word == word.reading && _dayFinished(state)) {
      actions.add(_autoReviewTab(state));
    }
    return _actionPage(actions);
  }

  _CardVisibility _visibilityFor(Vocabulary word, AppState state) =>
      _cardVisibility.putIfAbsent(
        word.id,
        () => _CardVisibility(
          showFurigana: state.showFurigana,
          hideWord: state.hideWord,
          hideMeanings: state.hideMeanings,
        ),
      );

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
        _restartAutoReview();
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
        _resumeDialogBarrierColor,
        Theme.of(context).scaffoldBackgroundColor,
      ),
    );
    setState(() => _resumeDialogVisible = true);
    bool? shouldResume;
    try {
      final dialogResult = showDialog<bool>(
        context: context,
        barrierColor: _resumeDialogBarrierColor,
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
      _restartAutoReview();
      return;
    }
    _suppressAutoAudio = true;
    _pageController!.jumpToPage(resumeIndex);
  }

  void _applySystemBarColorAfterFrame({required bool modalVisible}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _resumeDialogVisible != modalVisible) return;
      final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;
      final color = modalVisible
          ? Color.alphaBlend(_resumeDialogBarrierColor, scaffoldBackgroundColor)
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
    final readings = splitReadings(word.reading);
    if (readings.length > 1) {
      _speakReadings(readings);
    } else {
      _speak(word.word);
    }
  }

  Future<void> _speakIfAudible(String text, {Vocabulary? word}) async {
    // Slider mode sets the device volume itself when speaking, so only the
    // level chosen there can make speech inaudible.
    final settings = ref.read(appControllerProvider).value;
    String? warningKey;
    var playbackBlocked = false;
    if (settings?.ttsVolumeMode == TtsVolumeMode.slider) {
      if (settings!.ttsVolume <= lowVolumeThreshold) {
        warningKey = 'lowCustomVolumeBody';
      }
    } else {
      final volumeStatus = await getSystemVolumeStatus();
      warningKey = switch (volumeStatus) {
        SystemVolumeStatus.audible => null,
        SystemVolumeStatus.muted => 'mutedSystemVolumeBody',
        SystemVolumeStatus.low => 'lowSystemVolumeBody',
      };
      playbackBlocked = volumeStatus == SystemVolumeStatus.muted;
    }
    if (warningKey != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings(warningKey))));
      if (playbackBlocked) return;
    }
    if (!mounted) return;
    final readings = word == null ? const <String>[] : splitReadings(text);
    if (readings.length > 1) {
      _speakReadings(readings);
    } else {
      _speak(text);
    }
  }

  /// Auto review only runs on days already finished; a day still being
  /// studied for the first time keeps the manual controls and hides the
  /// auto review tab.
  bool _dayFinished(AppState state) =>
      state.completedStudyDays[state.selectedLevel]?.contains(widget.day) ??
      false;

  bool _autoReviewActive(AppState state) =>
      state.autoReviewEnabled && _dayFinished(state);

  /// Starts the current card over at its first element and, unless paused or
  /// waiting on the resume dialog, schedules the next reveal.
  void _restartAutoReview() {
    _autoTimer?.cancel();
    if (!mounted) return;
    if (_autoRevealed != 1) setState(() => _autoRevealed = 1);
    _scheduleAutoStep();
  }

  void _scheduleAutoStep() {
    _autoTimer?.cancel();
    final state = ref.read(appControllerProvider).value;
    if (state == null ||
        !_autoReviewActive(state) ||
        _autoPaused ||
        _resumeDecisionPending) {
      return;
    }
    _autoTimer = Timer(Duration(seconds: state.autoReviewSeconds), _onAutoStep);
  }

  void _onAutoStep() {
    if (!mounted) return;
    final state = ref.read(appControllerProvider).value;
    if (state == null || !_autoReviewActive(state)) return;
    if (_autoRevealed < state.autoReviewOrder.elements.length) {
      setState(() => _autoRevealed++);
      _scheduleAutoStep();
      return;
    }
    // Everything is revealed: move on. Past the last word this reaches the
    // trailing page, which finishes the session.
    unawaited(
      _pageController?.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ),
    );
  }

  void _toggleAutoReviewPause() {
    setState(() => _autoPaused = !_autoPaused);
    if (_autoPaused) {
      _autoTimer?.cancel();
    } else {
      _scheduleAutoStep();
    }
  }

  Future<void> _handlePageChanged({
    required int index,
    required List<Vocabulary> words,
    required AppState state,
  }) async {
    final request = ++_pageChangeRequest;
    if (index < words.length) _resetActionCarousel();
    if (_ttsService != null) await _ttsService!.stop();
    if (!mounted || request != _pageChangeRequest) return;

    if (index == words.length) {
      await _finishStudying();
      return;
    }
    setState(() => _index = index);
    if (_resumeDecisionPending) return;
    _restartAutoReview();
    unawaited(_savePosition(state, words[index], index));
    if (state.autoPlayAudio && !_suppressAutoAudio) {
      _speakWord(words[index]);
    }
    _suppressAutoAudio = false;
  }

  void _resetActionCarousel() {
    if (_currentActionPage.isEven || !_actionPageController.hasClients) return;
    final primaryPage = _currentActionPage - 1;
    _currentActionPage = primaryPage;
    _actionPageController.jumpToPage(primaryPage);
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
    required this.language,
    required this.showFurigana,
    required this.hideWord,
    required this.hideMeaning,
    required this.maskMeaningInTranslation,
    required this.onSpeakWord,
    required this.onSpeakExample,
  });

  final Vocabulary vocabulary;
  final String language;
  final bool showFurigana;
  final bool hideWord;
  final bool hideMeaning;
  final bool maskMeaningInTranslation;
  final VoidCallback onSpeakWord;
  final VoidCallback onSpeakExample;

  @override
  Widget build(BuildContext context) {
    return _centeredScrollable(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReading(context),
          const SizedBox(height: 6),
          _buildWord(context),
          const SizedBox(height: 10),
          const SizedBox(height: 18),
          _buildMeaning(context),
          if (vocabulary.hasExample) ...[
            const SizedBox(height: 34),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _buildExample(context),
            ),
          ],
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
    final titleLarge = Theme.of(context).textTheme.titleLarge;
    return AnimatedOpacity(
      opacity: hasReading ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        ignoring: !hasReading,
        child: _speechTarget(
          onTap: onSpeakWord,
          child: showFurigana
              ? Text(
                  vocabulary.reading,
                  style: titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : coverTapeFor(
                  characters: vocabulary.reading.length,
                  fontSize: titleLarge?.fontSize ?? 22,
                  maxWidth: 220,
                  glyphWidth: 0.9,
                ),
        ),
      ),
    );
  }

  Widget _buildWord(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      onTap: onSpeakWord,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: hideWord
              ? coverTapeFor(
                  characters: vocabulary.word.length,
                  fontSize: 56 * 1.15,
                  tilt: -0.02,
                )
              : Text(
                  vocabulary.word,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 56,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    ),
  );

  Widget _speechTarget({required VoidCallback onTap, required Widget child}) =>
      Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: child,
          ),
        ),
      );

  Widget _buildMeaning(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium;
    final meaning = vocabulary.meaning(language);
    if (!hideMeaning) {
      return Text(meaning, textAlign: TextAlign.center, style: style);
    }
    return coverTapeFor(
      characters: meaning.length,
      fontSize: style?.fontSize ?? 28,
      maxWidth: 260,
      glyphWidth: 0.7,
      tilt: 0.015,
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
        Semantics(
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            onTap: onSpeakExample,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _maskedText(
                _withRolePlayLineBreaks(vocabulary.example.sentence),
                style: sentenceStyle,
                targets: hideWord ? wordMaskTargets(vocabulary.word) : const [],
                glyphWidth: 1,
              ),
            ),
          ),
        ),
        if (showFurigana) ...[
          const SizedBox(height: 6),
          _speechTarget(
            onTap: onSpeakExample,
            child: Text(
              _withRolePlayLineBreaks(vocabulary.example.reading),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 4),
        _buildTranslation(context, translationStyle),
      ],
    );
  }

  Widget _buildTranslation(BuildContext context, TextStyle style) {
    final translation = _withRolePlayLineBreaks(
      vocabulary.example.translation(language),
    );
    // Korean meanings are inflected inside Korean translations, so they are
    // matched by lemma; other languages keep the plain substring mask.
    final koreanMeanings = vocabulary.meanings['ko'];
    if (language == 'ko' && koreanMeanings != null) {
      return MaskedTranslation(
        translation: translation,
        meanings: koreanMeanings,
        hideMeanings: maskMeaningInTranslation,
        style: style,
        glyphWidth: 0.55,
      );
    }
    return _maskedText(
      translation,
      style: style,
      targets: maskMeaningInTranslation
          ? meaningMaskTargets(
              vocabulary.meanings[language] ??
                  vocabulary.meanings['en'] ??
                  const [],
            )
          : const [],
      glyphWidth: 0.55,
    );
  }

  /// Renders [text] centered, laying tape over every run matching [targets].
  Widget _maskedText(
    String text, {
    required TextStyle? style,
    required List<String> targets,
    required double glyphWidth,
  }) {
    if (targets.isEmpty) {
      return Text(text, textAlign: TextAlign.center, style: style);
    }
    return MaskedSegmentsText(
      segments: maskSegments(text, targets),
      style: style,
      glyphWidth: glyphWidth,
    );
  }
}

String _withRolePlayLineBreaks(String text) => text.replaceAllMapped(
  RegExp(r'([.!?。！？])\s*(?=[A-Za-z][A-Za-z0-9]{0,2}\s*[：:])'),
  (match) => '${match.group(1)}\n',
);

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;

  /// Null makes the action inert and draws it semi-transparent.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.38 : 1,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );
}
