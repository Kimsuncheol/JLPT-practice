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

  /// Re-hides the system navigation bar. Call this after showing a dialog
  /// or bottom sheet on an immersive screen: presenting an overlay route can
  /// make Android redraw its window insets and reveal the (unstyled) system
  /// nav bar even though it was hidden before, and nothing else in this
  /// mixin re-hides it since that isn't a user-initiated swipe-down.
  void reassertImmersiveMode() => _hideSystemNavBar();

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

  /// Wrap a screen's root content so that:
  /// - swiping down outside of any scrollable (which claims vertical drags
  ///   itself) re-hides the system navigation bar once swiped into view.
  /// - the status bar and navigation bar always render in the screen's own
  ///   background color, so even a transient reveal (e.g. Android redrawing
  ///   insets while a dialog is presented) looks like part of the screen
  ///   instead of a mismatched black/white system strip. AnnotatedRegion is
  ///   declarative: the framework keeps it in sync automatically, no manual
  ///   re-application needed around dialogs or route transitions.
  Widget wrapImmersive(Widget child) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final iconBrightness =
        ThemeData.estimateBrightnessForColor(backgroundColor) ==
            Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: ThemeData.estimateBrightnessForColor(
          backgroundColor,
        ),
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarDividerColor: backgroundColor,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) {
          if (_systemNavBarVisible && details.delta.dy > 0) {
            _hideSystemNavBar();
          }
        },
        child: child,
      ),
    );
  }
}
