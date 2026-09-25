import 'package:volume_controller/volume_controller.dart';

/// Below this fraction of max volume, speech audio is effectively inaudible.
const lowVolumeThreshold = 0.3;

enum SystemVolumeStatus { audible, muted, low }

/// Distinguishes a muted device from an unmuted device whose media volume is
/// too low to hear TTS speech. If volume cannot be read, assumes it is audible
/// so the check never blocks playback outright.
Future<SystemVolumeStatus> getSystemVolumeStatus() async {
  try {
    final controller = VolumeController.instance;
    if (await controller.isMuted()) return SystemVolumeStatus.muted;
    final volume = await controller.getVolume();
    return volume <= lowVolumeThreshold
        ? SystemVolumeStatus.low
        : SystemVolumeStatus.audible;
  } catch (_) {
    return SystemVolumeStatus.audible;
  }
}
