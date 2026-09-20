import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemTtsAudioSession.create();
  runApp(const ProviderScope(child: JlptPracticeApp()));
}
