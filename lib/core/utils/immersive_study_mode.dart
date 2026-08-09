import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

mixin ImmersiveStudyMode<T extends StatefulWidget> on State<T> {
  bool _systemNavBarVisible = false;

  @override
  void initState() {
    super.initState();
    _hideSystemNavBar();
    SystemChrome.setSystemUIChangeCallback(_handleSystemUIChange);
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIChangeCallback(null);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _hideSystemNavBar() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }

  Future<void> _handleSystemUIChange(bool systemOverlaysAreVisible) async {
    if (!mounted) return;
    _systemNavBarVisible = systemOverlaysAreVisible;
  }

  /// Wrap a screen's root content so that swiping down outside of any
  /// scrollable (which claims vertical drags itself) re-hides the system
  /// navigation bar once the user has swiped it into view.
  Widget wrapImmersive(Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) {
        if (_systemNavBarVisible && details.delta.dy > 0) {
          _hideSystemNavBar();
        }
      },
      child: child,
    );
  }
}
