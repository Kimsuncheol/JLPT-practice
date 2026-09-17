import 'package:flutter/services.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';

class DeviceAiProbe {
  static const channel = MethodChannel('jlpt_practice/offline_ai');

  Future<DeviceAiCapacity> read() async {
    try {
      final map = await channel.invokeMapMethod<String, dynamic>('capacity');
      if (map == null) throw const OfflineAiException('offlineUnsupported');
      return DeviceAiCapacity(
        totalRam: (map['totalRam'] as num).toInt(),
        availableRam: (map['availableRam'] as num).toInt(),
        freeStorage: (map['freeStorage'] as num).toInt(),
        is64Bit: map['is64Bit'] == true,
        hot: map['hot'] == true,
        directory: map['directory'] as String,
      );
    } on PlatformException {
      throw const OfflineAiException('offlineUnsupported');
    } on MissingPluginException {
      throw const OfflineAiException('offlineUnsupported');
    }
  }
}
