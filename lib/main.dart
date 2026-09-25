import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/shared/keep_screen_on.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/fonts/OFL-NotoSansKR.txt',
    );
    yield LicenseEntryWithLineBreaks(['Noto Sans KR'], license);
  });
  await SystemTtsAudioSession.create();
  runApp(const ProviderScope(child: KeepScreenOn(child: JlptPracticeApp())));
}
