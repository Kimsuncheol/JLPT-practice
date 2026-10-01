import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/immersive_study_mode.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:jlpt_practice/data/repositories/kanji_repository.dart';
import 'package:jlpt_practice/features/kanji/kanji_card.dart';
import 'package:jlpt_practice/features/kanji/kanji_forward_lock_physics.dart';
import 'package:jlpt_practice/features/kanji/kanji_speech.dart';
import 'package:jlpt_practice/features/kanji/kanji_visibility.dart';
import 'package:jlpt_practice/features/kanji/widgets/kanji_footer.dart';
import 'package:jlpt_practice/features/vocabulary/day_selection_screen.dart';

class KanjiStudyScreen extends ConsumerStatefulWidget {
  const KanjiStudyScreen({required this.day, super.key});

  final int day;

  @override
  ConsumerState<KanjiStudyScreen> createState() => _KanjiStudyScreenState();
}

class _KanjiStudyScreenState extends ConsumerState<KanjiStudyScreen>
    with ImmersiveStudyMode<KanjiStudyScreen>, KanjiSpeech<KanjiStudyScreen> {
  static const _counterBottomPadding = 12.0;
  static const _counterTextHeight = 24.0;

  /// Gap between the hide group and the page indicator, as a share of the
  /// screen height.
  static const _hideGroupGapShare = 0.05;

  PageController? _pageController;
  final Map<String, KanjiVisibility> _visibility = {};

  /// The page the swipe cannot move on from, or null when it is not locked.
  int? _lockedPage = 0;

  /// Kanji whose back the learner has seen. Swiping on is locked until then.
  final Set<String> _seenBack = {};
  int _index = 0;
  bool _leaveDialogVisible = false;

  @override
  void dispose() {
    _pageController?.dispose();
    stopSpeech();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(appControllerProvider);
    final catalog = ref.watch(kanjiCatalogProvider);
    final Widget body;
    if (asyncState.hasError || catalog.hasError) {
      body = Scaffold(
        body: Center(child: Text('${asyncState.error ?? catalog.error}')),
      );
    } else if (!asyncState.hasValue || !catalog.hasValue) {
      body = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else {
      body = _buildStudyScreen(
        context,
        asyncState.requireValue,
        catalog.requireValue,
      );
    }
    return wrapImmersiveIncludingBottomInset(body);
  }

  Widget _buildStudyScreen(
    BuildContext context,
    AppState state,
    List<Kanji> catalog,
  ) {
    final kanji = StudyBatches.wordsForDay(
      kanjiForLevel(catalog, state.selectedLevel),
      day: widget.day,
      dailyGoal: state.dailyGoal,
    );
    if (kanji.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.strings('noResults'))),
      );
    }
    final controller = _pageController ?? _initializePage(kanji, state);
    final seenBack = _seenBack.contains(kanji[_index].id);
    _lockedPage = seenBack ? null : _index;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: () => context.push('/settings/learning'),
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
        // The pages fill the whole body, so a swipe works anywhere on screen;
        // only the page indicator floats over the foot of the card.
        body: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: controller,
                physics: KanjiForwardLockPhysics(lockedPage: () => _lockedPage),
                // One page past the last kanji: swiping onto it opens the finish screen.
                itemCount: kanji.length + 1,
                onPageChanged: (index) => _handlePageChanged(
                  index: index,
                  kanji: kanji,
                  state: state,
                ),
                itemBuilder: (context, index) => index == kanji.length
                    ? const SizedBox.shrink()
                    : _buildCard(
                        kanji[index],
                        state: state,
                        seenBack: seenBack,
                        isLast: index == kanji.length - 1,
                        controller: controller,
                      ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: _counterBottomPadding),
                  child: Center(
                    child: Text(
                      '${_index + 1} / ${kanji.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

  /// Asks before leaving; the position is already saved, so leaving loses only
  /// what was covered.
  Future<void> _confirmLeave() async {
    if (_leaveDialogVisible) return;
    _leaveDialogVisible = true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.strings('leaveKanjiTitle')),
        content: Text(dialogContext.strings('leaveKanjiBody')),
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
    );
    _leaveDialogVisible = false;
    if (mounted && shouldLeave == true) context.pop();
  }

  Widget _buildCard(
    Kanji item, {
    required AppState state,
    required bool seenBack,
    required bool isLast,
    required PageController controller,
  }) => KanjiCard(
    key: ValueKey(item.id),
    kanji: item,
    language: state.meaningLanguage,
    visibility: _visibilityFor(item, state),
    bottomInset: _hideGroupBottomInset(context),
    footer: KanjiFooter(seenBack: seenBack),
    onStartOver: isLast && seenBack ? () => controller.jumpToPage(0) : null,
    onVisibilityChanged: (value) =>
        setState(() => _visibility[item.id] = value),
    onSpeakReading: (reading) =>
        unawaited(speakTapped(kanjiReadingForSpeech(reading))),
    onSpeakSentence: (sentence) => unawaited(speakTapped(sentence)),
    onFlip: (showingBack) {
      stopSpeech();
      if (showingBack) setState(() => _seenBack.add(item.id));
    },
  );

  /// Space from the bottom of the card to the bottom of the hide group: the
  /// page indicator plus 5% of the screen height.
  double _hideGroupBottomInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom +
      _counterBottomPadding +
      _counterTextHeight +
      MediaQuery.sizeOf(context).height * _hideGroupGapShare;

  KanjiVisibility _visibilityFor(Kanji item, AppState state) =>
      _visibility.putIfAbsent(
        item.id,
        () => KanjiVisibility(
          hideKanji: state.hideWord,
          hideKunYomi: !state.showFurigana,
          hideOnYomi: !state.showFurigana,
          hideMeanings: state.hideMeanings,
        ),
      );

  /// Opens on the saved kanji when the learner left this day part-way, and
  /// otherwise on the first.
  PageController _initializePage(List<Kanji> kanji, AppState state) {
    final key = StudyCourse.kanji.progressKey(state.selectedLevel);
    final session = state.studySessions[key];
    final canResume =
        session != null &&
        session.day == widget.day &&
        session.isCompatible(level: key, dailyGoal: state.dailyGoal);
    _index = canResume
        ? session.resolveIndex(kanji.map((item) => item.id).toList())
        : 0;
    _lockedPage = _index;
    final controller = _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_savePosition(state, kanji[_index], _index));
      if (state.autoPlayAudio) _speakFirstReading(kanji[_index]);
    });
    return controller;
  }

  /// Remembers where the learner is, which also feeds "recent study".
  Future<void> _savePosition(AppState state, Kanji item, int index) => ref
      .read(appControllerProvider.notifier)
      .saveStudySession(
        StudySession(
          level: StudyCourse.kanji.progressKey(state.selectedLevel),
          day: widget.day,
          wordId: item.id,
          indexFallback: index,
          dailyGoal: state.dailyGoal,
          updatedAt: DateTime.now(),
        ),
      );

  void _handlePageChanged({
    required int index,
    required List<Kanji> kanji,
    required AppState state,
  }) {
    stopSpeech();
    if (index == kanji.length) {
      context.pushReplacement('/kanji/day/${widget.day}/finish');
      return;
    }
    setState(() => _index = index);
    unawaited(_savePosition(state, kanji[index], index));
    if (state.autoPlayAudio) _speakFirstReading(kanji[index]);
  }

  /// Automatic pronunciation reads the reading shown first on the front.
  void _speakFirstReading(Kanji item) {
    final reading =
        item.frontKunYomi.firstOrNull ?? item.frontOnYomi.firstOrNull;
    if (reading != null) speak(kanjiReadingForSpeech(reading));
  }
}
