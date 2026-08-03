import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/features/dashboard/home_shell.dart';
import 'package:jlpt_practice/features/chat/tutor_chat_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_detail_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_list_screen.dart';
import 'package:jlpt_practice/features/kana/kana_chart_screen.dart';
import 'package:jlpt_practice/features/onboarding/onboarding_screen.dart';
import 'package:jlpt_practice/features/quiz/quiz_result_screen.dart';
import 'package:jlpt_practice/features/quiz/quiz_screen.dart';
import 'package:jlpt_practice/features/review/review_screen.dart';
import 'package:jlpt_practice/features/settings/languages_screen.dart';
import 'package:jlpt_practice/features/settings/levels_screen.dart';
import 'package:jlpt_practice/features/test/mock_test_result_screen.dart';
import 'package:jlpt_practice/features/test/mock_test_screen.dart';
import 'package:jlpt_practice/features/vocabulary/day_selection_screen.dart';
import 'package:jlpt_practice/features/vocabulary/study_finish_screen.dart';
import 'package:jlpt_practice/features/vocabulary/study_screen.dart';
import 'package:jlpt_practice/shared/bootstrap_screen.dart';

GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const BootstrapScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/home', builder: (_, _) => const HomeShell()),
    GoRoute(path: '/chat', builder: (_, _) => const TutorChatScreen()),
    GoRoute(
      path: '/settings/languages',
      builder: (_, _) => const LanguagesScreen(),
    ),
    GoRoute(path: '/settings/levels', builder: (_, _) => const LevelsScreen()),
    GoRoute(path: '/study', builder: (_, _) => const DaySelectionScreen()),
    GoRoute(
      path: '/study/day/:day',
      builder: (_, state) => StudyScreen(
        day: int.tryParse(state.pathParameters['day'] ?? '') ?? 1,
      ),
    ),
    GoRoute(
      path: '/study/day/:day/finish',
      builder: (_, state) => StudyFinishScreen(
        day: int.tryParse(state.pathParameters['day'] ?? '') ?? 1,
      ),
    ),
    GoRoute(path: '/grammar', builder: (_, _) => const GrammarListScreen()),
    GoRoute(
      path: '/grammar/detail/:id',
      builder: (_, state) =>
          GrammarDetailScreen(grammarId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(path: '/quiz', builder: (_, _) => const QuizScreen()),
    GoRoute(
      path: '/quiz/day/:day',
      builder: (_, state) =>
          QuizScreen(day: int.tryParse(state.pathParameters['day'] ?? '')),
    ),
    GoRoute(path: '/quiz/result', builder: (_, _) => const QuizResultScreen()),
    GoRoute(path: '/test/n5', builder: (_, _) => const MockTestScreen()),
    GoRoute(
      path: '/test/n5/result',
      builder: (_, _) => const MockTestResultScreen(),
    ),
    GoRoute(path: '/review', builder: (_, _) => const ReviewScreen()),
    GoRoute(path: '/kana', builder: (_, _) => const KanaChartScreen()),
  ],
);

final appRouter = createAppRouter();
