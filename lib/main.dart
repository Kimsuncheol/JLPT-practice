import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app.dart';
import 'package:jlpt_practice/app/router.dart';
import 'package:jlpt_practice/core/ads/ad_service.dart';
import 'package:jlpt_practice/core/services/firebase_bootstrap.dart';
import 'package:jlpt_practice/core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  await NotificationService.instance.initialize();
  NotificationService.instance.onRoute = appRouter.go;
  await AdService.initialize();
  runApp(const ProviderScope(child: JlptPracticeApp()));
}
