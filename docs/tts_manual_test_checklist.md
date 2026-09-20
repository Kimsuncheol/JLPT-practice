# TTS audio-focus manual test checklist

Run every playback test twice: once before the Sherpa model is installed
(`flutter_tts`) and once after selecting/downloading a Sherpa voice.

## Android and iOS

For each background source — YouTube, Spotify, and a podcast app:

- Start background audio, return to JLPT Practice, and tap a word, reading,
  pronunciation, and example sentence.
- Confirm the external audio pauses, TTS is fully audible, and the external
  audio resumes after TTS finishes.
- Tap several different items rapidly. Only the last item should play; the
  external audio should remain paused across the handover and resume once.
- Stop or leave the study screen during speech. TTS should stop and the
  external audio should resume.
- Receive a phone call during speech. TTS should stop without crashing and
  should not restart automatically when the call ends.
- Unplug wired headphones or disconnect Bluetooth during speech. TTS should
  stop and must not unexpectedly continue through the speaker.
- Put the app in the background during speech. TTS should stop and release
  audio focus.
- With no external audio playing, confirm normal TTS volume and completion.

## Sherpa first use

- Remove the downloaded model, then trigger model installation from TTS
  settings. Confirm the UI remains responsive while the model downloads,
  extracts, and loads.
- While the first synthesis is slow, tap a second item. Confirm the stale first
  result never plays and only the second item is heard.
- Confirm generated temporary WAV files are removed after normal completion,
  cancellation, and playback failure.

## Platform notes

- Android uses transient focus (`gainTransient`), so cooperative media apps
  should pause and resume when focus is abandoned.
- iOS uses `playback` plus `interruptSpokenAudioAndMixWithOthers`, and session
  deactivation uses `notifyOthersOnDeactivation`.
- Automatic resume ultimately belongs to the external app. An app that ignores
  Android focus gain or iOS deactivation notification may remain paused.
