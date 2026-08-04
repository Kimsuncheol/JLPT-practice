import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/chat/tutor_chat_screen.dart';
import 'package:jlpt_practice/features/dashboard/dashboard_screen.dart';
import 'package:jlpt_practice/features/settings/settings_screen.dart';
import 'package:jlpt_practice/features/statistics/statistics_screen.dart';
import 'package:jlpt_practice/features/test/level_practice_test_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    TutorChatScreen(),
    _TestTab(),
    StatisticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: strings('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum_rounded),
            label: strings('tutor'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fact_check_outlined),
            selectedIcon: const Icon(Icons.fact_check_rounded),
            label: strings('n5Test'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: strings('progress'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_rounded),
            label: strings('settings'),
          ),
        ],
      ),
    );
  }
}

class _TestTab extends ConsumerWidget {
  const _TestTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level =
        ref.watch(appControllerProvider).value?.selectedLevel ?? 'N5';
    return LevelPracticeTestScreen(level: level);
  }
}
