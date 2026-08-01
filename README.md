# Kotoba Flow

An offline-first Flutter JLPT vocabulary app with English and Korean UI,
swipe study cards, text-to-speech, fill-in-the-blank quizzes,
spaced repetition, statistics, and an optional Firebase/AdMob integration.

## Run locally

```sh
flutter pub get
flutter run
```

The checked-in catalog contains 7,972 words grouped and ordered by N1–N5 from
`elzup/jlpt-word-list`. A small enriched subset supplies Korean meanings and
examples; other entries fall back to their source English meaning. All core
flows work without cloud credentials. Settings, quiz totals, and
SRS progress are saved with SharedPreferences.

Refresh the catalog from its upstream rank files with:

```sh
dart run tool/import_jlpt_catalog.dart
```

## Configure Firebase

1. Create Android and iOS apps in a Firebase project.
2. Enable Anonymous Authentication and Cloud Firestore.
3. Run `flutterfire configure`, or add `google-services.json` and
   `GoogleService-Info.plist` using the normal FlutterFire setup.
4. Deploy rules and indexes with `firebase deploy --only firestore`.
5. Enable App Check and Crashlytics for release builds.

If Firebase initialization fails, the app deliberately continues in local
mode. Cloud writes are kept in repositories/services and never issued by UI
widgets.

## Enable development ads

The source uses official Google test app and ad-unit IDs. Ads are opt-in:

```sh
flutter run --dart-define=ENABLE_ADS=true
```

Replace the sample application IDs, provide production unit IDs through build
configuration, and implement UMP consent before publishing. Vocabulary cards
never contain ad placements.

## Validate

```sh
dart format .
flutter analyze
flutter test
```

Release work still requiring owner credentials or policy decisions is tracked
in [PRIVACY.md](PRIVACY.md) and [ATTRIBUTION.md](ATTRIBUTION.md).
