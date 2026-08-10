import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jlpt_practice/core/utils/system_bar_metrics.dart';

mixin ImmersiveStudyMode<T extends StatefulWidget> on State<T> {
  bool _systemNavBarVisible = false;
  Color? _outerBackgroundColor;

  @override
  void initState() {
    super.initState();
    _hideSystemNavBar();
    SystemChrome.setSystemUIChangeCallback(_handleSystemUIChange);
  }

  @override
  void dispose() {
    if (SystemBarMetrics.outerBackgroundColor.value == _outerBackgroundColor) {
      SystemBarMetrics.outerBackgroundColor.value = null;
    }
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

  /// Applies the same style imperatively after an overlay route or system UI
  /// mode change. Android can otherwise retain the previous window-bar colors
  /// even though the underlying [AnnotatedRegion] has rebuilt.
  void applyImmersiveSystemBarColor(Color color) {
    SystemChrome.setSystemUIOverlayStyle(_systemBarStyle(color));
  }

  /// Colors the stable safe-area padding that wraps the app's root navigator.
  /// Dialog barriers are presented inside that padding and cannot tint it.
  void setImmersiveOuterBackgroundColor(Color? color) {
    _outerBackgroundColor = color;
    SystemBarMetrics.outerBackgroundColor.value = color;
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

  /// Wrap a screen's root content so that:
  /// - swiping down outside of any scrollable (which claims vertical drags
  ///   itself) re-hides the system navigation bar once swiped into view.
  /// - the status bar and navigation bar always render in the screen's own
  ///   background color, so even a transient reveal (e.g. Android redrawing
  ///   insets while a dialog is presented) looks like part of the screen
  ///   instead of a mismatched black/white system strip. AnnotatedRegion keeps
  ///   the normal screen state declarative; overlay routes can additionally
  ///   call [applyImmersiveSystemBarColor] after they are presented.
  Widget wrapImmersive(Widget child, {Color? systemBarColor}) {
    final backgroundColor =
        systemBarColor ?? Theme.of(context).scaffoldBackgroundColor;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemBarStyle(backgroundColor),
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

  SystemUiOverlayStyle _systemBarStyle(Color backgroundColor) {
    final backgroundBrightness = ThemeData.estimateBrightnessForColor(
      backgroundColor,
    );
    final iconBrightness = backgroundBrightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: backgroundColor,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: backgroundBrightness,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: backgroundColor,
      systemNavigationBarDividerColor: backgroundColor,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarContrastEnforced: false,
    );
  }
}
