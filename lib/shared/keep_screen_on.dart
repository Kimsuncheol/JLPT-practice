import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

typedef KeepScreenOnOperation = Future<void> Function();

class KeepScreenOnController {
  KeepScreenOnController({
    KeepScreenOnOperation? enable,
    KeepScreenOnOperation? disable,
  }) : _enable = enable ?? WakelockPlus.enable,
       _disable = disable ?? WakelockPlus.disable;

  static final instance = KeepScreenOnController();

  final KeepScreenOnOperation _enable;
  final KeepScreenOnOperation _disable;
  int _activeScreens = 0;

  void acquire() {
    _activeScreens++;
    if (_activeScreens == 1) unawaited(_run(_enable));
  }

  void release() {
    if (_activeScreens == 0) return;
    _activeScreens--;
    if (_activeScreens == 0) unawaited(_run(_disable));
  }

  Future<void> _run(KeepScreenOnOperation operation) async {
    try {
      await operation();
    } catch (_) {
      // The feature is best-effort on platforms without wake-lock support.
    }
  }
}

class KeepScreenOn extends StatefulWidget {
  const KeepScreenOn({required this.child, this.controller, super.key});

  final Widget child;
  final KeepScreenOnController? controller;

  @override
  State<KeepScreenOn> createState() => _KeepScreenOnState();
}

class _KeepScreenOnState extends State<KeepScreenOn> {
  late KeepScreenOnController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? KeepScreenOnController.instance;
    _controller.acquire();
  }

  @override
  void didUpdateWidget(KeepScreenOn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextController = widget.controller ?? KeepScreenOnController.instance;
    if (identical(_controller, nextController)) return;
    _controller.release();
    _controller = nextController;
    _controller.acquire();
  }

  @override
  void dispose() {
    _controller.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
