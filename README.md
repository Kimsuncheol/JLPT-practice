# Kotoba Flow

An offline-first Flutter JLPT vocabulary and grammar app with English and
Korean UI, swipe study cards, text-to-speech, fill-in-the-blank quizzes,
spaced repetition, statistics, and an optional Firebase/AdMob integration.

## Run locally

```sh
flutter pub get
flutter run
```

The checked-in catalogs contain 8,449 words and 828 grammar points grouped and
ordered by N1–N5 from `tristcoil/hanabira.org`. Every vocabulary record has an
example sentence, and every one of the 3,310 upstream grammar examples is
included. All core flows work without cloud credentials. Settings, quiz totals, and
SRS progress are saved with SharedPreferences.

Refresh the catalog from its upstream rank files with:

```sh
dart run tool/import_jlpt_catalog.dart
dart run tool/import_hanabira_grammar.dart
dart run tool/translate_hanabira_grammar_google.dart
```

Rebuild the ranked mock-exam bank from the retained legacy reference bank with:

```sh
dart run tool/build_ranked_mock_bank.dart
dart run tool/validate_ranked_mock_bank.dart
```

The app combines historical source dates into item-type pools. For every level,
Reading, Listening, Grammar, and Vocabulary each offer Practice 1–10 while
covering every published JLPT item type. The original
`jlpt_test_problems_2021_2025.csv` is preserved and is not loaded by the live
mock-test flow.

## Configure Firebase

1. Create Android and iOS apps in a Firebase project.
2. Enable Anonymous, Email/Password, Google, and Apple Authentication plus
   Cloud Firestore. Add Android SHA fingerprints and refresh both Firebase
   configuration files so they contain the OAuth client IDs.
3. Run `flutterfire configure`, or add `google-services.json` and
   `GoogleService-Info.plist` using the normal FlutterFire setup.
4. Deploy rules and the account-deletion function with
   `firebase deploy --only firestore:rules,functions`.
5. Enable App Check and Crashlytics for release builds.

If Firebase initialization fails, the app deliberately continues in local
mode. Cloud access is encapsulated in dedicated services.

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
