import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

class OfflineAiScreen extends StatelessWidget {
  const OfflineAiScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings('grammarChatTitle'))),
    body: Center(child: Text(context.strings('aiFeaturesUnavailable'))),
  );
}
