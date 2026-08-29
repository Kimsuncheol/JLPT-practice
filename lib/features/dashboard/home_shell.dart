import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/dashboard/dashboard_screen.dart';
import 'package:jlpt_practice/features/dashboard/home_tab_provider.dart';
import 'package:jlpt_practice/features/profile/profile_screen.dart';
import 'package:jlpt_practice/features/settings/settings_screen.dart';
import 'package:jlpt_practice/features/statistics/statistics_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _screens = [
    DashboardScreen(),
    StatisticsScreen(),
    ProfileScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final index = ref.watch(homeTabIndexProvider);
    return Scaffold(
      body: IndexedStack(index: index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            ref.read(homeTabIndexProvider.notifier).select(value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: strings('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: strings('progress'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: strings('me'),
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
