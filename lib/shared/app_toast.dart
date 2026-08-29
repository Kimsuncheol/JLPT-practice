import 'dart:async';

import 'package:flutter/material.dart';

/// Shows a brief, self-dismissing toast near the bottom of the screen.
/// Unlike a [SnackBar] it floats above the current route via [Overlay] and
/// doesn't require (or compete with) a [Scaffold]'s [ScaffoldMessenger].
void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) =>
        _Toast(message: message, onDismissed: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
    Future.delayed(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.paddingOf(context).bottom + 32,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _opacity,
          child: Align(
            child: Material(
              color: theme.colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(24),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
