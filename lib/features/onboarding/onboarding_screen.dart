import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _level = 'N5';
  int _goal = 10;
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppTheme.mint,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '語',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      strings('onboardingTitle'),
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings('onboardingBody'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _Label(strings('chooseLevel')),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 9,
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
                    const SizedBox(height: 28),
                    _Label(strings('dailyGoal')),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 5, label: Text('5')),
                        ButtonSegment(value: 10, label: Text('10')),
                        ButtonSegment(value: 20, label: Text('20')),
                        ButtonSegment(value: 30, label: Text('30')),
                      ],
                      selected: {_goal},
                      onSelectionChanged: (value) {
                        setState(() => _goal = value.first);
                      },
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 28),
                    _Label(strings('language')),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 18),
                    SwitchListTile(
                      value: _autoAudio,
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings('autoAudio')),
                      secondary: const Icon(Icons.volume_up_rounded),
                      onChanged: (value) {
                        setState(() => _autoAudio = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.swipe_rounded),
                          const SizedBox(width: 12),
                          Expanded(child: Text(strings('swipeHint'))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _submitting
                          ? null
                          : () async {
                              setState(() => _submitting = true);
                              await ref
                                  .read(appControllerProvider.notifier)
                                  .completeOnboarding(
                                    level: _level,
                                    dailyGoal: _goal,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
