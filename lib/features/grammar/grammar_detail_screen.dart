import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/core/services/volume_service.dart';
import 'package:jlpt_practice/shared/volume_warning_toast.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/vocabulary/example_furigana_text.dart';
import 'package:jlpt_practice/data/models/grammar_study_session.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/grammar/grammar_qa_chat_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_study_session_provider.dart';
import 'package:jlpt_practice/core/constants/app_colors.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

class GrammarDetailScreen extends ConsumerWidget {
  const GrammarDetailScreen({required this.grammarId, super.key});

  final String grammarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(grammarCatalogProvider);
    return catalog.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
        ),
        body: Center(child: Text(error.toString())),
      ),
      data: (items) {
        final grammar = _findGrammar(items, grammarId);
        if (grammar == null) {
          return Scaffold(
            appBar: AppBar(
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
            ),
            body: Center(child: Text(context.strings('noGrammarResults'))),
          );
        }
        return TrackGrammarStudy(
          key: ValueKey(grammar.id),
          session: GrammarStudySession(
            level: grammar.level,
            part: (grammar.rank - 1) ~/ 10 + 1,
            kind: GrammarStudyKind.detail,
            grammarId: grammar.id,
            title: grammar.title,
            updatedAt: DateTime.now(),
          ),
          child: _GrammarDetails(grammar: grammar),
        );
      },
    );
  }
}

class _GrammarDetails extends ConsumerStatefulWidget {
  const _GrammarDetails({required this.grammar});

  final GrammarPoint grammar;

  @override
  ConsumerState<_GrammarDetails> createState() => _GrammarDetailsState();
}

class _GrammarDetailsState extends ConsumerState<_GrammarDetails> {
  TtsService? _ttsService;

  @override
  void dispose() {
    if (_ttsService != null) unawaited(_ttsService!.stop());
    super.dispose();
  }

  void _speak(String text) {
    _ttsService ??= ref.read(ttsServiceProvider);
    unawaited(_ttsService!.speak(text));
  }

  Future<void> _speakIfAudible(String text) async {
    final volumeStatus = await getSystemVolumeStatus();
    if (volumeStatus != SystemVolumeStatus.audible) {
      if (!mounted) return;
      final warningKey = volumeStatus == SystemVolumeStatus.muted
          ? 'mutedSystemVolumeBody'
          : 'lowSystemVolumeBody';
      showVolumeWarningToast(context, context.strings(warningKey));
      if (volumeStatus == SystemVolumeStatus.muted) return;
    }
    _speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final grammar = widget.grammar;
    final meaningLanguage = ref
        .watch(appControllerProvider)
        .value
        ?.meaningLanguage;
    final language =
        meaningLanguage ?? Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final menuBackgroundColor = isDark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surface;
    final menuBorderColor = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.6 : 0.8,
    );
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('${grammar.level} · #${grammar.rank}'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings/learning'),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.size20,
          AppSizes.size10,
          AppSizes.size20,
          AppSizes.size32,
        ),
        children: [
          Text(
            grammar.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSizes.space10),
          Text(
            grammar.localizedSummary(language),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSizes.space24),
          _DetailSection(
            title: context.strings('formation'),
            child: SelectableText(
              grammar.localizedFormation(language),
              key: PageStorageKey('${grammar.id}-formation'),
            ),
          ),
          const SizedBox(height: AppSizes.space22),
          _DetailSection(
            title: context.strings('explanation'),
            child: SelectableText(
              grammar.localizedExplanation(language),
              key: PageStorageKey('${grammar.id}-explanation'),
            ),
          ),
          const SizedBox(height: AppSizes.space26),
          Text(
            context.strings('examples'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSizes.space12),
          ...grammar.examples.indexed.map(
            (indexed) => _ExampleCard(
              number: indexed.$1 + 1,
              example: indexed.$2,
              language: language,
              onSpeak: () => _speakIfAudible(indexed.$2.japanese),
            ),
          ),
        ],
      ),
      floatingActionButton: MenuAnchor(
        key: const ValueKey('grammar_detail_ai_menu'),
        alignmentOffset: const Offset(0, -AppSizes.size8),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(menuBackgroundColor),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(AppPalette.shadow20),
          elevation: const WidgetStatePropertyAll(AppSizes.size6),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: AppSizes.size8),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius18),
              side: BorderSide(color: menuBorderColor),
            ),
          ),
        ),
        menuChildren: [
          MenuItemButton(
            key: const ValueKey('grammar_detail_practice_with_ai'),
            leadingIcon: Icon(
              Icons.auto_awesome_rounded,
              color: colorScheme.primary,
            ),
            onPressed: () => context.push(
              '/grammar/tutor/${Uri.encodeComponent(grammar.id)}',
            ),
            child: Text(
              context.strings('practiceWithAi'),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: AppFontWeights.semiBold,
              ),
            ),
          ),
          MenuItemButton(
            key: const ValueKey('grammar_detail_tutor'),
            leadingIcon: Icon(
              Icons.question_answer_rounded,
              color: colorScheme.primary,
            ),
            onPressed: () => showGrammarQaChatScreen(
              context,
              grammar: grammar,
              languageCode: language,
            ),
            child: Text(
              context.strings('grammarChatTitle'),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: AppFontWeights.semiBold,
              ),
            ),
          ),
        ],
        builder: (context, controller, child) => FloatingActionButton(
          key: const ValueKey('grammar_detail_ai_trigger'),
          shape: const CircleBorder(),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: const Icon(Icons.auto_awesome_rounded),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSizes.size20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSizes.radius22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSizes.space9),
        child,
      ],
    ),
  );
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.number,
    required this.example,
    required this.language,
    required this.onSpeak,
  });

  final int number;
  final GrammarExample example;
  final String language;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('grammar-example-container-$number'),
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: AppSizes.size12),
    padding: const EdgeInsets.all(AppSizes.size18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            onTap: onSpeak,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$number.', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: AppSizes.space8),
                Expanded(
                  child: ExampleFuriganaText(
                    key: ValueKey('grammar-example-$number'),
                    segments: example.sentenceSegments,
                    style:
                        Theme.of(context).textTheme.titleLarge ??
                        const TextStyle(fontSize: 22),
                    wordTargets: const [],
                    hideReadings: false,
                    alignment: WrapAlignment.start,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.space7),
        Text(
          example.translation(language),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

GrammarPoint? _findGrammar(List<GrammarPoint> items, String id) {
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
}
