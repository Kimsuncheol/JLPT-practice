import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/router.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/core/utils/system_bar_metrics.dart';
import 'package:jlpt_practice/shared/network_status_screen.dart';

class JlptPracticeApp extends ConsumerWidget {
  const JlptPracticeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    final locale = asyncState.when<Locale?>(
      data: (state) =>
          state.languageCode == 'system' ? null : Locale(state.languageCode),
      loading: () => null,
      error: (_, _) => null,
    );
    final themeMode = asyncState.when(
      data: (state) => state.themeMode,
      loading: () => ThemeMode.system,
      error: (_, _) => ThemeMode.system,
    );
    return MaterialApp.router(
      title: 'Kotoba Flow',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final liveBottom = mediaQuery.padding.bottom;
        if (liveBottom > 0) {
          SystemBarMetrics.bottomInset = liveBottom;
        }
        final stableMediaQuery = mediaQueryWithStableSystemInsets(
          mediaQuery,
          SystemBarMetrics.bottomInset,
        );
        return MediaQuery(
          data: stableMediaQuery,
          child: NetworkStatusGate(
            child: ValueListenableBuilder<Color?>(
              valueListenable: SystemBarMetrics.outerBackgroundColor,
              builder: (context, outerBackgroundColor, appChild) => ColoredBox(
                color:
                    outerBackgroundColor ??
                    Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(child: appChild ?? const SizedBox.shrink()),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ko')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

MediaQueryData mediaQueryWithStableSystemInsets(
  MediaQueryData mediaQuery,
  double bottomInset,
) {
  // In immersive landscape mode Android can change padding.right when the
  // navigation bar is revealed. viewPadding retains the system UI footprint,
  // so using the larger value keeps SafeArea—and therefore the study card—at
  // a constant width while the bar appears or disappears.
  final leftInset = math.max(
    mediaQuery.padding.left,
    mediaQuery.viewPadding.left,
  );
  final rightInset = math.max(
    mediaQuery.padding.right,
    mediaQuery.viewPadding.right,
  );

  return mediaQuery.copyWith(
    padding: mediaQuery.padding.copyWith(
      left: leftInset,
      right: rightInset,
      bottom: bottomInset,
    ),
    viewPadding: mediaQuery.viewPadding.copyWith(
      left: leftInset,
      right: rightInset,
      bottom: bottomInset,
    ),
  );
}
