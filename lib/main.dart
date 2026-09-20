import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app.dart';
import 'package:jlpt_practice/core/ads/ad_service.dart';
import 'package:jlpt_practice/core/services/firebase_bootstrap.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  await AdService.initialize();
  // Keep the screen awake for the app's entire lifetime; this is not a
  // user-configurable preference, so there is no corresponding setting.
  unawaited(WakelockPlus.enable());
  runApp(const ProviderScope(child: JlptPracticeApp()));
}
