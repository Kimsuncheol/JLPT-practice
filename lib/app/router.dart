import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/features/dashboard/home_shell.dart';
import 'package:jlpt_practice/features/grammar/grammar_list_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_rank_screen.dart';
import 'package:jlpt_practice/features/onboarding/onboarding_screen.dart';
import 'package:jlpt_practice/features/quiz/quiz_result_screen.dart';
import 'package:jlpt_practice/features/quiz/quiz_screen.dart';
import 'package:jlpt_practice/features/review/review_screen.dart';
import 'package:jlpt_practice/features/settings/languages_screen.dart';
import 'package:jlpt_practice/features/settings/levels_screen.dart';
import 'package:jlpt_practice/features/vocabulary/day_selection_screen.dart';
import 'package:jlpt_practice/features/vocabulary/study_screen.dart';
import 'package:jlpt_practice/shared/bootstrap_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const BootstrapScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/home', builder: (_, _) => const HomeShell()),
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
    GoRoute(path: '/grammar', builder: (_, _) => const GrammarRankScreen()),
    GoRoute(
      path: '/grammar/study',
      builder: (_, _) => const GrammarListScreen(),
    ),
    GoRoute(path: '/quiz', builder: (_, _) => const QuizScreen()),
    GoRoute(path: '/quiz/result', builder: (_, _) => const QuizResultScreen()),
    GoRoute(path: '/review', builder: (_, _) => const ReviewScreen()),
  ],
);
