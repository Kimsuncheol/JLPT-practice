import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/ads/ad_service.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/shared/rewarded_xp_card.dart';

class MockTestResultScreen extends ConsumerStatefulWidget {
  const MockTestResultScreen({super.key, required this.retryPath});

  final String retryPath;

  @override
  ConsumerState<MockTestResultScreen> createState() =>
      _MockTestResultScreenState();
}

class _MockTestResultScreenState extends ConsumerState<MockTestResultScreen> {
  bool _sessionRecorded = false;

  String _sectionLabel(BuildContext context, TestSectionType type) =>
      switch (type) {
        TestSectionType.vocabulary => context.strings('sectionVocabulary'),
        TestSectionType.grammar => context.strings('grammar'),
        TestSectionType.reading => context.strings('sectionReading'),
        TestSectionType.listening => context.strings('sectionListening'),
      };

  @override
  Widget build(BuildContext context) {
    final result = ref
        .watch(appControllerProvider)
        .requireValue
        .lastMockTestResult;
    if (result == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/home');
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    if (!_sessionRecorded) {
      _sessionRecorded = true;
      Future<void>.delayed(
        const Duration(milliseconds: 900),
        AdService.recordCompletedSession,
      );
    }
    final percentage = (result.accuracy * 100).round();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 20),
                child: Column(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        percentage >= 70
                            ? Icons.celebration_rounded
                            : Icons.auto_awesome_rounded,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      context.strings('mockTestComplete'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        fontSize: 58,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      context.strings('accuracy'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _ResultMetric(
                            icon: Icons.check_circle_rounded,
                            value: '${result.correct}',
                            label: context.strings('correctAnswers'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ResultMetric(
                            icon: Icons.refresh_rounded,
                            value: '${result.incorrect}',
                            label: context.strings('incorrect'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ResultMetric(
                            icon: Icons.timer_outlined,
                            value: '${result.duration.inSeconds}s',
                            label: context.strings('duration'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.strings('sectionResults'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          for (final section in result.sections)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _sectionLabel(context, section.type),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${section.correct}/${section.total}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    FilledButton.icon(
                      onPressed: () => context.go(widget.retryPath),
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(context.strings('retry')),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: Text(context.strings('backHome')),
                    ),
                  ],
                ),
              ),
            ),
            const RewardedXpCard(),
          ],
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 9),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}
