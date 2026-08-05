import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/dashboard/dashboard_screen.dart';
import 'package:jlpt_practice/features/review/review_screen.dart';
import 'package:jlpt_practice/features/settings/settings_screen.dart';
import 'package:jlpt_practice/features/statistics/statistics_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    ReviewScreen(),
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
            icon: const Icon(Icons.replay_circle_filled_outlined),
            selectedIcon: const Icon(Icons.replay_circle_filled_rounded),
            label: strings('review'),
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
