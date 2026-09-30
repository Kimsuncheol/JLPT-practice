import 'package:flutter/widgets.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/volume_service.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';
import 'package:jlpt_practice/shared/volume_warning_toast.dart';

/// Warns when speech would be too quiet to hear and reports whether playback
/// should go ahead (it should not when the device is muted).
///
/// Slider mode sets the device volume itself when speaking, so only the level
/// chosen there can make speech inaudible.
Future<bool> confirmSpeechAudible(
  BuildContext context,
  AppState? settings,
) async {
  String? warningKey;
  var playbackBlocked = false;
  if (settings?.ttsVolumeMode == TtsVolumeMode.slider) {
    if (settings!.ttsVolume <= lowVolumeThreshold) {
      warningKey = 'lowCustomVolumeBody';
    }
  } else {
    final volumeStatus = await getSystemVolumeStatus();
    warningKey = switch (volumeStatus) {
      SystemVolumeStatus.audible => null,
      SystemVolumeStatus.muted => 'mutedSystemVolumeBody',
      SystemVolumeStatus.low => 'lowSystemVolumeBody',
    };
    playbackBlocked = volumeStatus == SystemVolumeStatus.muted;
  }
  if (!context.mounted) return false;
  if (warningKey != null) {
    showVolumeWarningToast(context, context.strings(warningKey));
    if (playbackBlocked) return false;
  }
  return true;
}
