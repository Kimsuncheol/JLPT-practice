import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';

/// Warm amber tint for a strength [level] in 0..1.
Color eyeComfortTint(double level) => const Color(
  0xFFFFA726,
).withValues(alpha: 0.05 + 0.30 * level.clamp(0.0, 1.0));

/// Lays the user's eye comfort tint over a study screen. Touches pass through.
class EyeComfortOverlay extends ConsumerWidget {
  const EyeComfortOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(
      appControllerProvider.select(
        (async) => async.value == null
            ? null
            : (async.value!.eyeComfortEnabled, async.value!.eyeComfortLevel),
      ),
    );
    if (settings == null || !settings.$1) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: eyeComfortTint(settings.$2)),
          ),
        ),
      ],
    );
  }
}
