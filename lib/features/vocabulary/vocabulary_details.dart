import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

void showVocabularyDetails(
  BuildContext context,
  Vocabulary vocabulary,
  String language,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (_) =>
        VocabularyDetails(vocabulary: vocabulary, language: language),
  );
}

class VocabularyDetails extends ConsumerWidget {
  const VocabularyDetails({
    required this.vocabulary,
    required this.language,
    super.key,
  });

  final Vocabulary vocabulary;
  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleParts = [
      if (vocabulary.word.compareTo(vocabulary.reading) != 0)
        vocabulary.reading,
      if (vocabulary.word.compareTo(vocabulary.romaji) != 0)
        vocabulary.romaji,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vocabulary.word,
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitleParts.isNotEmpty)
                      Text(
                        subtitleParts.join('  ·  '),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () =>
                    ref.read(ttsServiceProvider).speak(vocabulary.word),
                icon: const Icon(Icons.volume_up_rounded),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text('${vocabulary.jlptLevel} · #${vocabulary.rank}'),
              ),
              Chip(label: Text(vocabulary.partOfSpeech)),
              ...vocabulary.tags.take(2).map((tag) => Chip(label: Text(tag))),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            context.strings('meaning'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            vocabulary.meaning(language),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (vocabulary.hasExample) ...[
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings('example'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    vocabulary.example.sentence,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(vocabulary.example.reading),
                  const SizedBox(height: 10),
                  Text(
                    vocabulary.example.translation(language),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
