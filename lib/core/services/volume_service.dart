import 'package:volume_controller/volume_controller.dart';

/// Below this fraction of max volume, speech audio is effectively inaudible.
const lowVolumeThreshold = 0.05;

/// Whether the device is muted or its volume is too low to hear TTS speech.
/// Returns `false` (i.e. assume audible) if the volume can't be read on this
/// platform, so the check never blocks playback outright.
Future<bool> isSystemVolumeTooLow() async {
  try {
    final controller = VolumeController.instance;
    if (await controller.isMuted()) return true;
    final volume = await controller.getVolume();
    return volume <= lowVolumeThreshold;
  } catch (_) {
    return false;
  }
}
