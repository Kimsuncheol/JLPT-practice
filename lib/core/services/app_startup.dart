import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/ads/ad_service.dart';
import 'package:jlpt_practice/core/services/firebase_bootstrap.dart';
import 'package:jlpt_practice/core/services/notification_service.dart';

final appStartupProvider = FutureProvider<void>((ref) async {
  await _tryInitialize('System UI', () async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  });
  await FirebaseBootstrap.initialize();
  await _tryInitialize(
    'Notifications',
    NotificationService.instance.initialize,
  );
  await _tryInitialize('Ads', AdService.initialize);
});

Future<void> _tryInitialize(
  String service,
  Future<void> Function() initialize,
) async {
  try {
    await initialize();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('$service unavailable during startup: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
