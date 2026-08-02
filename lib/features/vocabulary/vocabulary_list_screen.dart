import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/vocabulary/vocabulary_details.dart';
import 'package:jlpt_practice/features/vocabulary/vocabulary_list_skeleton.dart';
import 'package:jlpt_practice/features/vocabulary/vocabulary_tile.dart';
import 'package:jlpt_practice/shared/adaptive_ad_slot.dart';
import 'package:jlpt_practice/shared/empty_state.dart';

class VocabularyListScreen extends ConsumerStatefulWidget {
  const VocabularyListScreen({super.key});

  @override
  ConsumerState<VocabularyListScreen> createState() =>
      _VocabularyListScreenState();
}

class _VocabularyListScreenState extends ConsumerState<VocabularyListScreen> {
  String _query = '';
  String _level = 'All';
  String _partOfSpeech = 'All';

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(appControllerProvider);
    return SafeArea(
      child: asyncState.when(
        loading: () => const VocabularyListSkeleton(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final items =
              state.vocabulary.where((item) {
                return (_level == 'All' || item.jlptLevel == _level) &&
                    (_partOfSpeech == 'All' ||
                        item.partOfSpeech == _partOfSpeech) &&
                    item.matches(_query, state.meaningLanguage);
              }).toList()..sort((a, b) {
                final levelComparison = _levelOrder[a.jlptLevel]!.compareTo(
                  _levelOrder[b.jlptLevel]!,
                );
                return levelComparison != 0
                    ? levelComparison
                    : a.rank.compareTo(b.rank);
              });
          final parts = {
            'All',
            ...state.vocabulary.map((item) => item.partOfSpeech),
          }.toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings('words'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: context.strings('search'),
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ['All', 'N5', 'N4', 'N3', 'N2', 'N1']
                            .map(
                              (level) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    level == 'All'
                                        ? context.strings('all')
                                        : level,
                                  ),
                                  selected: _level == level,
                                  onSelected: (_) =>
                                      setState(() => _level = level),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _partOfSpeech,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.filter_list_rounded),
                        isDense: true,
                      ),
                      items: parts
                          .map(
                            (part) => DropdownMenuItem(
                              value: part,
                              child: Text(
                                part == 'All' ? context.strings('all') : part,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _partOfSpeech = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: context.strings('noResults'),
                        body: context.strings('search'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return VocabularyTile(
                            vocabulary: item,
                            language: state.meaningLanguage,
                            onTap: () => showVocabularyDetails(
                              context,
                              item,
                              state.meaningLanguage,
                            ),
                          );
                        },
                      ),
              ),
              const AdaptiveAdSlot(),
            ],
          );
        },
      ),
    );
  }
}

const _levelOrder = {'N5': 0, 'N4': 1, 'N3': 2, 'N2': 3, 'N1': 4};
