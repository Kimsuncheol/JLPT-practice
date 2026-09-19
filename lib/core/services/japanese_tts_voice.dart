class JapaneseTtsVoice {
  const JapaneseTtsVoice({
    required this.id,
    required this.sid,
    required this.name,
    required this.descriptionKey,
  });

  final String id;
  final int sid;
  final String name;
  final String descriptionKey;
}

/// Character presets backed by Supertonic 3's multi-speaker voice table.
const japaneseTtsVoices = [
  JapaneseTtsVoice(
    id: 'f1',
    sid: 0,
    name: 'Aoi',
    descriptionKey: 'ttsVoiceClearFemale',
  ),
  JapaneseTtsVoice(
    id: 'f3',
    sid: 2,
    name: 'Hana',
    descriptionKey: 'ttsVoiceWarmFemale',
  ),
  JapaneseTtsVoice(
    id: 'f5',
    sid: 4,
    name: 'Rin',
    descriptionKey: 'ttsVoiceLightFemale',
  ),
  JapaneseTtsVoice(
    id: 'm2',
    sid: 6,
    name: 'Yuki',
    descriptionKey: 'ttsVoiceSoftMale',
  ),
  JapaneseTtsVoice(
    id: 'm4',
    sid: 8,
    name: 'Sora',
    descriptionKey: 'ttsVoiceCalmMale',
  ),
];

JapaneseTtsVoice japaneseTtsVoiceById(String id) =>
    japaneseTtsVoices.firstWhere(
      (voice) => voice.id == id,
      orElse: () => japaneseTtsVoices.first,
    );
