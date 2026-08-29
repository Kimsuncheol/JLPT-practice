import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jlpt_practice/core/utils/system_bar_metrics.dart';

mixin ImmersiveStudyMode<T extends StatefulWidget> on State<T> {
  Color? _outerBackgroundColor;

  @override
  void initState() {
    super.initState();
    _showSystemBars();
  }

  @override
  void dispose() {
    if (SystemBarMetrics.outerBackgroundColor.value == _outerBackgroundColor) {
      SystemBarMetrics.outerBackgroundColor.value = null;
    }
    super.dispose();
  }

  /// Reasserts that both system bars remain visible after an overlay closes.
  void reassertImmersiveMode() => _showSystemBars();

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

  void _showSystemBars() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  /// Styles the always-visible status and navigation bars to match the screen.
  Widget wrapImmersive(Widget child, {Color? systemBarColor}) {
    final backgroundColor =
        systemBarColor ?? Theme.of(context).scaffoldBackgroundColor;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemBarStyle(backgroundColor),
      child: child,
    );
  }

  /// Keeps existing call sites simple while dialogs retain normal gestures.
  Widget wrapImmersiveSystemBarGesture(Widget child) => child;

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
