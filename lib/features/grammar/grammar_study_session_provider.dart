import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/services/local_store.dart';
import 'package:jlpt_practice/data/models/grammar_study_session.dart';

final grammarStudySessionsProvider =
    AsyncNotifierProvider<
      GrammarStudySessionsController,
      Map<String, GrammarStudySession>
    >(GrammarStudySessionsController.new);

class GrammarStudySessionsController
    extends AsyncNotifier<Map<String, GrammarStudySession>> {
  late LocalStore _store;
  Future<void> _write = Future.value();

  @override
  Future<Map<String, GrammarStudySession>> build() async {
    _store = await LocalStore.create();
    return _store.loadGrammarStudySessions();
  }

  Future<void> record(GrammarStudySession session) async {
    await future;
    final next = {...state.requireValue, session.level: session};
    state = AsyncData(next);
    _write = _write.then((_) => _store.saveGrammarStudySessions(next));
    await _write;
  }
}

/// Records entry once, after the screen has loaded valid grammar content.
class TrackGrammarStudy extends ConsumerStatefulWidget {
  const TrackGrammarStudy({
    required this.session,
    required this.child,
    super.key,
  });

  final GrammarStudySession session;
  final Widget child;

  @override
  ConsumerState<TrackGrammarStudy> createState() => _TrackGrammarStudyState();
}

class _TrackGrammarStudyState extends ConsumerState<TrackGrammarStudy> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(grammarStudySessionsProvider.notifier).record(widget.session);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
