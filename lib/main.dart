import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app.dart';
import 'package:jlpt_practice/core/ads/ad_service.dart';
import 'package:jlpt_practice/core/services/firebase_bootstrap.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch every error that reaches the top of the widget tree (including
    // errors from fire-and-forget async calls like cloud sync or TTS) so it
    // gets reported instead of crashing the whole app.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _reportError(details.exception, details.stack ?? StackTrace.current);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _reportError(error, stack);
      return true;
    };

    await FirebaseBootstrap.initialize();
    await AdService.initialize();
    // Keep the screen awake for the app's entire lifetime; this is not a
    // user-configurable preference, so there is no corresponding setting.
    unawaited(WakelockPlus.enable());
    runApp(const ProviderScope(child: JlptPracticeApp()));
  }, _reportError);
}

void _reportError(Object error, StackTrace stack) {
  if (FirebaseBootstrap.isAvailable) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
    );
  }
  if (kDebugMode) {
    debugPrint('Unhandled error: $error');
    debugPrintStack(stackTrace: stack);
  }
}
