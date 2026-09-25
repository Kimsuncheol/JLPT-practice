import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

typedef KeepScreenOnOperation = Future<void> Function();

class KeepScreenOnController {
  KeepScreenOnController({KeepScreenOnOperation? enable})
    : _enable = enable ?? WakelockPlus.enable;

  static final instance = KeepScreenOnController();

  final KeepScreenOnOperation _enable;

  void enable() => unawaited(_run(_enable));

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

class _KeepScreenOnState extends State<KeepScreenOn>
    with WidgetsBindingObserver {
  late KeepScreenOnController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = widget.controller ?? KeepScreenOnController.instance;
    _controller.enable();
  }

  @override
  void didUpdateWidget(KeepScreenOn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextController = widget.controller ?? KeepScreenOnController.instance;
    if (identical(_controller, nextController)) return;
    _controller = nextController;
    _controller.enable();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.enable();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
