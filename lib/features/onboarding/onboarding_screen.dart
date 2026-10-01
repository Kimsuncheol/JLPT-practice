import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';
import 'package:jlpt_practice/core/constants/app_spacing.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _level = 'N5';
  String? _language;
  bool _autoAudio = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    _language ??= 'system';
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.size24,
                AppSizes.size24,
                AppSizes.size24,
                AppSizes.size32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: AppSizes.size64,
                      height: AppSizes.size64,
                      decoration: const BoxDecoration(
                        color: AppTheme.mint,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '語',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: AppSizes.font30,
                          fontWeight: AppFontWeights.extraBold,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.space30),
                    Text(
                      strings('onboardingTitle'),
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: AppSizes.space12),
                    Text(
                      strings('onboardingBody'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSizes.space36),
                    _Label(strings('chooseLevel')),
                    const SizedBox(height: AppSizes.space12),
                    Wrap(
                      spacing: AppSpacing.item9,
                      children: ['N5', 'N4', 'N3', 'N2', 'N1']
                          .map(
                            (level) => ChoiceChip(
                              label: Text(level),
                              selected: _level == level,
                              onSelected: (_) => setState(() => _level = level),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSizes.space28),
                    _Label(strings('language')),
                    const SizedBox(height: AppSizes.space12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'system', label: Text('System')),
                        ButtonSegment(value: 'en', label: Text('English')),
                        ButtonSegment(value: 'ko', label: Text('한국어')),
                      ],
                      selected: {_language!},
                      onSelectionChanged: (value) {
                        setState(() => _language = value.first);
                      },
                    ),
                    const SizedBox(height: AppSizes.space18),
                    SwitchListTile(
                      value: _autoAudio,
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings('autoAudio')),
                      secondary: const Icon(Icons.volume_up_rounded),
                      onChanged: (value) {
                        setState(() => _autoAudio = value);
                      },
                    ),
                    const SizedBox(height: AppSizes.space14),
                    Container(
                      padding: const EdgeInsets.all(AppSizes.size16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppSizes.radius18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.swipe_rounded),
                          const SizedBox(width: AppSizes.space12),
                          Expanded(child: Text(strings('swipeHint'))),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.space32),
                    FilledButton(
                      onPressed: _submitting
                          ? null
                          : () async {
                              setState(() => _submitting = true);
                              await ref
                                  .read(appControllerProvider.notifier)
                                  .completeOnboarding(
                                    level: _level,
                                    languageCode: _language!,
                                    autoPlayAudio: _autoAudio,
                                  );
                              if (context.mounted) context.go('/home');
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                      ),
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: AppSizes.size2,
                              ),
                            )
                          : Text(strings('getStarted')),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);
}
