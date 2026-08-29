import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/core/services/volume_service.dart';
import 'package:jlpt_practice/core/utils/immersive_study_mode.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/review_progress.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

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
  bool? _showFurigana;
  PageController? _pageController;
  TtsService? _ttsService;
  bool _resumeDecisionPending = false;
  bool _resumeDialogVisible = false;
  bool _suppressAutoAudio = false;

  @override
  void initState() {
    super.initState();
    // The app is locked to portrait everywhere else (see main.dart); this
    // screen alone has a landscape layout, so it briefly allows rotation
    // into it and restores the app-wide lock on dispose.
    unawaited(
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  }

  @override
  void dispose() {
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    _pageController?.dispose();
    if (_ttsService != null) unawaited(_ttsService!.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(appControllerProvider);
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
    _showFurigana ??= state.showFurigana;
    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.strings('noResults'))),
      );
    }
    _initializePage(words, state);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: words.length + 1,
              onPageChanged: (index) {
                if (index == words.length) {
                  unawaited(_finishStudying());
                  return;
                }
                setState(() => _index = index);
                if (_resumeDecisionPending) return;
                unawaited(_savePosition(state, words[index], index));
                if (state.autoPlayAudio && !_suppressAutoAudio) {
                  _speak(words[index].word);
                }
                _suppressAutoAudio = false;
              },
              itemBuilder: (context, index) {
                if (index == words.length) return const SizedBox.shrink();
                final word = words[index];
                return Padding(
                  padding: isLandscape
                      ? const EdgeInsets.fromLTRB(8, 2, 8, 2)
                      : const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: _StudyCard(
                    vocabulary: word,
                    language: state.meaningLanguage,
                    showFurigana: _showFurigana!,
                    onToggleFurigana: () {
                      setState(() => _showFurigana = !_showFurigana!);
                    },
                    onSpeakWord: () => _speakIfAudible(word.reading),
                    onSpeakExample: () =>
                        _speakIfAudible(word.example.sentence),
                    onReview: () async {
                      await ref
                          .read(appControllerProvider.notifier)
                          .rateVocabulary(word.id, ReviewRating.again);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.strings('markReview')),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: isLandscape
                  ? const EdgeInsets.fromLTRB(20, 2, 20, 6)
                  : const EdgeInsets.fromLTRB(20, 6, 20, 14),
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
    _index = 0;
    _pageController = PageController();
    _resumeDecisionPending = canResume;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (canResume) {
        unawaited(_confirmResume(session, words));
      } else {
        unawaited(_savePosition(state, words.first, 0));
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

    if (resumeIndex == 0) return;
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

  void _speak(String text) {
    _ttsService ??= ref.read(ttsServiceProvider);
    unawaited(_ttsService!.speak(text));
  }

  Future<void> _speakIfAudible(String text) async {
    if (await isSystemVolumeTooLow()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings('lowVolumeBody'))));
      return;
    }
    _speak(text);
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

class _StudyCard extends StatelessWidget {
  const _StudyCard({
    required this.vocabulary,
    required this.language,
    required this.showFurigana,
    required this.onToggleFurigana,
    required this.onSpeakWord,
    required this.onSpeakExample,
    required this.onReview,
  });

  final Vocabulary vocabulary;
  final String language;
  final bool showFurigana;
  final VoidCallback onToggleFurigana;
  final VoidCallback onSpeakWord;
  final VoidCallback onSpeakExample;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return isLandscape ? _buildLandscape(context) : _buildPortrait(context);
  }

  Widget _buildPortrait(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Column(
              children: [
                _buildChips(),
                const SizedBox(height: 44),
                _buildReading(context),
                const SizedBox(height: 6),
                _buildWord(context),
                const SizedBox(height: 10),
                _buildRomaji(context),
                const SizedBox(height: 8),
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
          ),
        ),
        const SizedBox(height: 15),
        _buildActionsRow(context),
      ],
    );
  }

  Widget _buildLandscape(BuildContext context) {
    final identityColumn = Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChips(),
                  const SizedBox(height: 18),
                  _buildReading(context),
                  const SizedBox(height: 6),
                  _buildWord(context),
                  const SizedBox(height: 8),
                  _buildRomaji(context),
                  const SizedBox(height: 6),
                  _buildMeaning(context),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _buildActionsRow(context),
        const SizedBox(height: 6),
      ],
    );

    if (!vocabulary.hasExample) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: identityColumn,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 2, child: identityColumn),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: _buildExample(context),
          ),
        ),
      ],
    );
  }

  Widget _buildChips() {
    if (vocabulary.partOfSpeech == 'word') return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Chip(label: Text(vocabulary.partOfSpeech))],
    );
  }

  Widget _buildReading(BuildContext context) => AnimatedOpacity(
    opacity: showFurigana && vocabulary.reading.compareTo(vocabulary.word) != 0
        ? 1
        : 0,
    duration: const Duration(milliseconds: 180),
    child: Text(
      vocabulary.reading,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

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
          child: Text(
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

  Widget _buildRomaji(BuildContext context) => Text(
    vocabulary.romaji,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );

  Widget _buildMeaning(BuildContext context) => Text(
    vocabulary.meaning(language),
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.headlineMedium,
  );

  Widget _buildExample(BuildContext context) => Column(
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
            child: Text(
              _withRolePlayLineBreaks(vocabulary.example.sentence),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
      ),
      if (showFurigana) ...[
        const SizedBox(height: 6),
        Text(
          _withRolePlayLineBreaks(vocabulary.example.reading),
          textAlign: TextAlign.center,
        ),
      ],
      const SizedBox(height: 4),
      Text(
        _withRolePlayLineBreaks(vocabulary.example.translation(language)),
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );

  Widget _buildActionsRow(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _CardAction(
        icon: showFurigana
            ? Icons.visibility_off_rounded
            : Icons.visibility_rounded,
        label: showFurigana
            ? context.strings('hideReading')
            : context.strings('showReading'),
        onTap: onToggleFurigana,
      ),
      _CardAction(
        icon: Icons.bookmark_add_outlined,
        label: context.strings('markReview'),
        onTap: onReview,
      ),
    ],
  );
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );
}
