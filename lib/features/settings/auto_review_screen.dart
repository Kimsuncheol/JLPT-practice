import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';

/// "Word → Meanings → Reading": the localized name of a reveal order.
String autoReviewOrderLabel(BuildContext context, AutoReviewOrder order) =>
    order.elements
        .map((element) => context.strings(_elementKey(element)))
        .join(' → ');

/// "3 sec" / "3초": the localized length of one auto review step.
String autoReviewSecondsLabel(BuildContext context, int seconds) =>
    context.strings('autoReviewSecondsFormat').replaceAll('{n}', '$seconds');

String _elementKey(ReviewElement element) => switch (element) {
  ReviewElement.word => 'elementWord',
  ReviewElement.meanings => 'elementMeanings',
  ReviewElement.reading => 'elementReading',
};

/// Settings for the study screen's auto review: whether it runs, the order a
/// card's word, meanings and reading are revealed in, and how long each step
/// lasts.
class AutoReviewScreen extends ConsumerWidget {
  const AutoReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('autoReview'))),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final controller = ref.read(appControllerProvider.notifier);
          final strings = context.strings;
          final colors = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                child: Text(
                  strings('autoReviewHint'),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              _Group(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.play_circle_outline_rounded),
                    title: Text(strings('autoReviewEnable')),
                    value: state.autoReviewEnabled,
                    onChanged: controller.setAutoReviewEnabled,
                  ),
                ],
              ),
              _Label(strings('autoReviewOrder')),
              _Group(
                children: [
                  RadioGroup<AutoReviewOrder>(
                    groupValue: state.autoReviewOrder,
                    onChanged: (order) {
                      if (order != null) controller.setAutoReviewOrder(order);
                    },
                    child: Column(
                      children: [
                        for (final order in AutoReviewOrder.all)
                          RadioListTile<AutoReviewOrder>(
                            value: order,
                            title: Text(autoReviewOrderLabel(context, order)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              _Label(strings('autoReviewSpeed')),
              _Group(
                children: [
                  RadioGroup<int>(
                    groupValue: state.autoReviewSeconds,
                    onChanged: (seconds) {
                      if (seconds != null) {
                        controller.setAutoReviewSeconds(seconds);
                      }
                    },
                    child: Column(
                      children: [
                        for (final seconds in autoReviewSecondsOptions)
                          RadioListTile<int>(
                            value: seconds,
                            title: Text(
                              autoReviewSecondsLabel(context, seconds),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}
