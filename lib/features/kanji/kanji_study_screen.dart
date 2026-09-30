import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/core/utils/immersive_study_mode.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/data/repositories/kanji_repository.dart';
import 'package:jlpt_practice/features/kanji/kanji_card.dart';
import 'package:jlpt_practice/features/vocabulary/audible_speech.dart';
import 'package:jlpt_practice/features/vocabulary/day_selection_screen.dart';
import 'package:jlpt_practice/features/vocabulary/start_over_button.dart';

class KanjiStudyScreen extends ConsumerStatefulWidget {
  const KanjiStudyScreen({required this.day, super.key});

  final int day;

  @override
  ConsumerState<KanjiStudyScreen> createState() => _KanjiStudyScreenState();
}

class _KanjiStudyScreenState extends ConsumerState<KanjiStudyScreen>
    with ImmersiveStudyMode<KanjiStudyScreen> {
  final PageController _pageController = PageController();
  final Map<String, KanjiVisibility> _visibility = {};

  static const _actionsHeight = 72.0;
  static const _counterBottomPadding = 12.0;
  static const _counterTextHeight = 24.0;

  /// Gap between the hide group and the page indicator, as a share of the
  /// screen height.
  static const _hideGroupGapShare = 0.05;

  /// The page the swipe cannot move on from, or null when it is not locked.
  int? _lockedPage = 0;

  /// Kanji whose back the learner has seen. Swiping on is locked until then.
  final Set<String> _seenBack = {};
  TtsService? _ttsService;
  int _index = 0;
  bool _autoPlayScheduled = false;

  /// Bumped whenever speech is stopped, so a tap still waiting on the volume
  /// check cannot start speaking after the learner has moved on.
  int _speechRequest = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _stopSpeech();
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
    _scheduleAutoPlayOfFirst(kanji.first, state);
    final isLast = _index == kanji.length - 1;
    final seenBack = _seenBack.contains(kanji[_index].id);
    _lockedPage = seenBack ? null : _index;
    return Scaffold(
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
              controller: _pageController,
              physics: _ForwardLockPhysics(lockedPage: () => _lockedPage),
              itemCount: kanji.length,
              onPageChanged: (index) => _handlePageChanged(
                index: index,
                kanji: kanji,
                autoPlay: state.autoPlayAudio,
              ),
              itemBuilder: (context, index) {
                final item = kanji[index];
                return KanjiCard(
                  key: ValueKey(item.id),
                  bottomInset: _hideGroupBottomInset(context),
                  footer: SizedBox(
                    height: _actionsHeight,
                    child: !seenBack
                        ? Center(
                            child: Text(
                              context.strings('flipToContinue'),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : isLast
                        ? _buildLastCardActions(state)
                        : null,
                  ),
                  kanji: item,
                  language: state.meaningLanguage,
                  visibility: _visibilityFor(item, state),
                  onVisibilityChanged: (value) =>
                      setState(() => _visibility[item.id] = value),
                  onSpeakReading: (reading) =>
                      unawaited(_speakTapped(kanjiReadingForSpeech(reading))),
                  onSpeakSentence: (sentence) =>
                      unawaited(_speakTapped(sentence)),
                  onFlip: (showingBack) {
                    _stopSpeech();
                    if (showingBack) setState(() => _seenBack.add(item.id));
                  },
                );
              },
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
    );
  }

  /// Space from the bottom of the card to the bottom of the hide group: the
  /// page indicator plus 5% of the screen height.
  double _hideGroupBottomInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom +
      _counterBottomPadding +
      _counterTextHeight +
      MediaQuery.sizeOf(context).height * _hideGroupGapShare;

  Widget _buildLastCardActions(AppState state) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      StartOverButton(
        label: context.strings('startOver'),
        onPressed: () => _pageController.jumpToPage(0),
      ),
      const SizedBox(width: 24),
      FilledButton.icon(
        onPressed: () => unawaited(_finish(state)),
        icon: const Icon(Icons.check_rounded),
        label: Text(context.strings('finish')),
      ),
    ],
  );

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

  Future<void> _finish(AppState state) async {
    _stopSpeech();
    await ref
        .read(appControllerProvider.notifier)
        .completeStudySession(
          StudyCourse.kanji.progressKey(state.selectedLevel),
          widget.day,
        );
    if (!mounted) return;
    // go('/kanji') would leave the day list as the only route, so the system
    // back button would close the app. Rebuild home → day list instead.
    context.go('/home');
    context.push('/kanji');
  }

  void _handlePageChanged({
    required int index,
    required List<Kanji> kanji,
    required bool autoPlay,
  }) {
    _stopSpeech();
    setState(() => _index = index);
    if (autoPlay) _speakFirstReading(kanji[index]);
  }

  /// The first card is on screen from the start, so no page change fires to
  /// trigger automatic pronunciation for it.
  void _scheduleAutoPlayOfFirst(Kanji first, AppState state) {
    if (_autoPlayScheduled) return;
    _autoPlayScheduled = true;
    if (!state.autoPlayAudio) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _index == 0) _speakFirstReading(first);
    });
  }

  /// Automatic pronunciation reads the reading shown first on the front.
  void _speakFirstReading(Kanji item) {
    final reading =
        item.frontKunYomi.firstOrNull ?? item.frontOnYomi.firstOrNull;
    if (reading != null) _speak(kanjiReadingForSpeech(reading));
  }

  Future<void> _speakTapped(String speech) async {
    final request = ++_speechRequest;
    final settings = ref.read(appControllerProvider).value;
    if (!await confirmSpeechAudible(context, settings)) return;
    if (!mounted || request != _speechRequest) return;
    _speak(speech);
  }

  /// Speaks [speech] alone: a bare reading or one example sentence.
  void _speak(String speech) {
    _ttsService ??= ref.read(ttsServiceProvider);
    unawaited(_ttsService!.speak(speech));
  }

  void _stopSpeech() {
    _speechRequest++;
    final service = _ttsService;
    if (service != null) unawaited(service.stop());
  }
}

/// Lets a [PageView] scroll back freely but stops it moving forward past
/// [lockedPage], the page the learner is on until they flip its card.
class _ForwardLockPhysics extends ScrollPhysics {
  const _ForwardLockPhysics({required this.lockedPage, super.parent});

  /// Read on every scroll movement: a [Scrollable] keeps the physics it was
  /// created with, so the lock cannot be swapped by rebuilding with new physics.
  final ValueGetter<int?> lockedPage;

  @override
  _ForwardLockPhysics applyTo(ScrollPhysics? ancestor) => _ForwardLockPhysics(
    lockedPage: lockedPage,
    parent: buildParent(ancestor),
  );

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final locked = lockedPage();
    if (locked != null && value > position.pixels) {
      final limit = locked * position.viewportDimension;
      if (value > limit) {
        // Refuse the part of this movement that lies beyond the limit.
        return position.pixels >= limit - 0.001
            ? value - position.pixels
            : value - limit;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }
}
