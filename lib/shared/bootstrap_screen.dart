import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';

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
    context.go(onboardingComplete ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
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
    final background = isDark
        ? const Color(0xFF101713)
        : const Color(0xFFF8F5ED);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ColoredBox(
      color: background,
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              top: 70,
              left: -34,
              child: _DecorativeCircle(size: 112, color: Color(0x33E9755E)),
            ),
            const Positioned(
              right: -46,
              bottom: 104,
              child: _DecorativeCircle(size: 152, color: Color(0x44567563)),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _entrance,
                      child: const _StudyMark(),
                    ),
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: _controller,
                      child: Column(
                        children: [
                          Text(
                            '合格まで、あと一歩！',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: 30,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '今日の一歩が、明日の自信に。',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(color: muted),
                          ),
                          const SizedBox(height: 30),
                          const _LoadingDots(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Text(
                'KOTOBA FLOW  •  JLPT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        color: AppTheme.mint,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24567563),
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
                fontSize: 62,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Positioned(
            top: -9,
            right: -9,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFE9755E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
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
          _Dot(color: Color(0xFF567563)),
          SizedBox(width: 7),
          _Dot(color: Color(0xFF8BAD97)),
          SizedBox(width: 7),
          _Dot(color: Color(0xFFE9755E)),
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
    width: 8,
    height: 8,
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 16),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
