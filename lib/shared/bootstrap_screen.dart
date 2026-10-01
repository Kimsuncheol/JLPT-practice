import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/core/services/app_startup.dart';
import 'package:jlpt_practice/core/services/firebase_bootstrap.dart';
import 'package:jlpt_practice/core/services/notification_service.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_colors.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  static const _minimumDisplayTime = Duration(milliseconds: 1200);

  Timer? _timer;
  bool _minimumTimeElapsed = false;
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_minimumDisplayTime, () {
      if (!mounted) return;
      _minimumTimeElapsed = true;
      _continueIfReady();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _continueIfReady() {
    final onboardingComplete = _onboardingComplete;
    if (!mounted || !_minimumTimeElapsed || onboardingComplete == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (FirebaseBootstrap.isAvailable && (user == null || user.isAnonymous)) {
      context.go('/sign-in');
      return;
    }
    final initialRoute = NotificationService.instance.takeInitialRoute();
    context.go(onboardingComplete ? initialRoute ?? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(appStartupProvider);
    if (startup.isLoading) {
      return const Scaffold(body: SplashScreenContent());
    }
    if (startup.hasError) {
      return Scaffold(
        body: _SplashError(
          error: startup.error!,
          onRetry: () => ref.invalidate(appStartupProvider),
        ),
      );
    }

    final state = ref.watch(appControllerProvider);
    ref.listen(appControllerProvider, (_, next) {
      next.whenData((value) {
        _onboardingComplete = value.onboardingComplete;
        _continueIfReady();
      });
    });

    state.whenData((value) {
      _onboardingComplete = value.onboardingComplete;
      WidgetsBinding.instance.addPostFrameCallback((_) => _continueIfReady());
    });

    return Scaffold(
      body: state.when(
        data: (_) => const SplashScreenContent(),
        loading: () => const SplashScreenContent(),
        error: (error, _) => _SplashError(
          error: error,
          onRetry: () => ref.invalidate(appControllerProvider),
        ),
      ),
    );
  }
}

class SplashScreenContent extends StatefulWidget {
  const SplashScreenContent({super.key});

  @override
  State<SplashScreenContent> createState() => _SplashScreenContentState();
}

class _SplashScreenContentState extends State<SplashScreenContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entrance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _entrance = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppPalette.backgroundDark : AppPalette.cream;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ColoredBox(
      color: background,
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              top: AppSizes.size70,
              left: -34,
              child: _DecorativeCircle(
                size: AppSizes.size112,
                color: AppPalette.coralAlpha20,
              ),
            ),
            const Positioned(
              right: -46,
              bottom: AppSizes.size104,
              child: _DecorativeCircle(
                size: AppSizes.size152,
                color: AppPalette.sageAlpha27,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.size32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _entrance,
                      child: const _StudyMark(),
                    ),
                    const SizedBox(height: AppSizes.space36),
                    FadeTransition(
                      opacity: _controller,
                      child: Column(
                        children: [
                          Text(
                            '合格まで、あと一歩！',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: AppSizes.font30,
                                  height: AppSizes.lineHeight1_25,
                                  fontWeight: AppFontWeights.extraBold,
                                ),
                          ),
                          const SizedBox(height: AppSizes.space10),
                          Text(
                            '今日の一歩が、明日の自信に。',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(color: muted),
                          ),
                          const SizedBox(height: AppSizes.space30),
                          const _LoadingDots(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: AppSizes.size0,
              right: AppSizes.size0,
              bottom: AppSizes.size28,
              child: Text(
                'JLPT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: AppSizes.font11,
                  fontWeight: AppFontWeights.bold700,
                  letterSpacing: 2.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyMark extends StatelessWidget {
  const _StudyMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.size132,
      height: AppSizes.size132,
      decoration: BoxDecoration(
        color: AppTheme.mint,
        borderRadius: BorderRadius.circular(AppSizes.radius40),
        boxShadow: const [
          BoxShadow(
            color: AppPalette.sageAlpha14,
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Center(
            child: Text(
              '語',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: AppSizes.font62,
                height: AppSizes.size1,
                fontWeight: AppFontWeights.extraBold,
              ),
            ),
          ),
          Positioned(
            top: -9,
            right: -9,
            child: Container(
              width: AppSizes.size38,
              height: AppSizes.size38,
              decoration: const BoxDecoration(
                color: AppPalette.coral,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppPalette.white,
                size: AppSizes.size20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: AppPalette.sage),
          SizedBox(width: AppSizes.space7),
          _Dot(color: AppPalette.sageLight),
          SizedBox(width: AppSizes.space7),
          _Dot(color: AppPalette.coral),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: AppSizes.size8,
    height: AppSizes.size8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _SplashError extends StatelessWidget {
  const _SplashError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.size32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: AppSizes.size48),
              const SizedBox(height: AppSizes.space16),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: AppSizes.space16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
