import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';

/// Warm amber tint for a strength [level] in 0..1.
Color eyeComfortTint(double level) => const Color(
  0xFFFFA726,
).withValues(alpha: 0.05 + 0.30 * level.clamp(0.0, 1.0));

/// How many [EyeComfortOverlay] screens are on the navigator stack. While it
/// is above zero, [EyeComfortSystemBarTint] tints the system bar areas too.
final ValueNotifier<int> eyeComfortScreens = ValueNotifier(0);

/// Lays the user's eye comfort tint over a study screen. Touches pass through.
/// The tint stops at the safe area; [EyeComfortSystemBarTint] covers the
/// status and navigation bars.
class EyeComfortOverlay extends ConsumerStatefulWidget {
  const EyeComfortOverlay({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<EyeComfortOverlay> createState() => _EyeComfortOverlayState();
}

class _EyeComfortOverlayState extends ConsumerState<EyeComfortOverlay> {
  @override
  void initState() {
    super.initState();
    // Deferred: the notifier's listeners rebuild during this build phase.
    Future.microtask(() => eyeComfortScreens.value++);
  }

  @override
  void dispose() {
    Future.microtask(() => eyeComfortScreens.value--);
    super.dispose();
  }

  Widget get child => widget.child;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(
      appControllerProvider.select(
        (async) => async.value == null
            ? null
            : (async.value!.eyeComfortEnabled, async.value!.eyeComfortLevel),
      ),
    );
    // Always wrap in a Stack: switching between the bare child and a Stack
    // would re-parent the child and reset its state (e.g. a study screen
    // underneath would reopen its resume dialog).
    final enabled = settings != null && settings.$1;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (enabled)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: eyeComfortTint(settings.$2)),
            ),
          ),
      ],
    );
  }
}

/// Tints the status bar, navigation bar and side cutout areas that lie outside
/// the app's safe area while an eye comfort screen is showing.
class EyeComfortSystemBarTint extends ConsumerWidget {
  const EyeComfortSystemBarTint({
    required this.insets,
    required this.child,
    super.key,
  });

  final EdgeInsets insets;
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
    return ValueListenableBuilder<int>(
      valueListenable: eyeComfortScreens,
      // The child stays first so its state survives the tint toggling.
      builder: (context, screens, _) {
        final tinted = settings != null && settings.$1 && screens > 0;
        final tint = tinted ? eyeComfortTint(settings.$2) : null;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (tint != null) ...[
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: insets.top,
                child: IgnorePointer(child: ColoredBox(color: tint)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: insets.bottom,
                child: IgnorePointer(child: ColoredBox(color: tint)),
              ),
              Positioned(
                left: 0,
                top: insets.top,
                bottom: insets.bottom,
                width: insets.left,
                child: IgnorePointer(child: ColoredBox(color: tint)),
              ),
              Positioned(
                right: 0,
                top: insets.top,
                bottom: insets.bottom,
                width: insets.right,
                child: IgnorePointer(child: ColoredBox(color: tint)),
              ),
            ],
          ],
        );
      },
    );
  }
}
