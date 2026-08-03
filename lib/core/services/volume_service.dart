import 'package:flutter_volume_controller/flutter_volume_controller.dart';

/// Below this fraction of max volume, speech audio is effectively inaudible.
const lowVolumeThreshold = 0.05;

/// Whether the device is muted or its volume is too low to hear TTS speech.
/// Returns `false` (i.e. assume audible) if the volume can't be read on this
/// platform, so the check never blocks playback outright.
Future<bool> isSystemVolumeTooLow() async {
  try {
    final isMuted = await FlutterVolumeController.getMute();
    if (isMuted == true) return true;
    final volume = await FlutterVolumeController.getVolume();
    return volume != null && volume <= lowVolumeThreshold;
  } catch (_) {
    return false;
  }
}
