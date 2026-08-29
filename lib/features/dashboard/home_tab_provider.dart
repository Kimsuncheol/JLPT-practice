import 'package:flutter_riverpod/flutter_riverpod.dart';

const int homeTabDashboard = 0;
const int homeTabStatistics = 1;
const int homeTabProfile = 2;
const int homeTabSettings = 3;

/// The selected tab in [HomeShell]'s bottom navigation. Exposed as a
/// provider so screens hosted inside one tab (e.g. Settings) can switch to
/// another tab (e.g. Profile) without a route push.
class HomeTabIndexNotifier extends Notifier<int> {
  @override
  int build() => homeTabDashboard;

  void select(int index) => state = index;
}

final homeTabIndexProvider = NotifierProvider<HomeTabIndexNotifier, int>(
  HomeTabIndexNotifier.new,
);
