# JLPT study

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

## JLPT tutor API

AI screens use `https://jlpt-practice-langchain-muj9.onrender.com` by default.
No Gemini/Firebase AI credentials or on-device models are required. Ordinary
lessons and ranked practice tests continue to work offline.

- Vocabulary → open a study day → tap the sparkle icon in the top bar →
  **Word explanation** opens a `flutter_gen_ai_chat_ui` chat and immediately
  calls `POST /api/words/explain` for the current word and example sentence,
  without displaying an initial user question bubble,
  with the word's JLPT level and selected meaning language
  (English/Korean/Japanese; other languages fall back to English).
  The request supports a word of 1–100 characters and optional context up to 500.
  The full explanation appears as a Markdown AI message, including readings,
  meanings/POS, collocations, grammar, original AI examples, nuances, register,
  synonyms, usage contrasts, and separately labeled server-curated past-exam
  references when available. References reflect backend collection metadata;
  the app does not independently verify them. Exactly three follow-up questions
  arrive with the explanation in one call and appear in its message footer.
  Tap a question or type in the composer to continue through `/api/tutor/chat`
  in the same conversation with bounded word context and recent history.
  Errors keep the conversation and allow manual retry. Explanations and chats
  stay in memory and are discarded when the screen closes. This requires a
  backend deployment that includes `/api/words/explain`.
- Grammar → AI menu → **Grammar Tutor** uses `POST /api/tutor/chat` with
  lesson context. **Practise with AI** opens a guided conversation; its quiz
  icon creates a question focused on that grammar point using
  `POST /api/practice/question`.
- Answer a practice-test question → **Ask AI Tutor** uses `POST /api/tutor`
  with the selected question, passage, answer key, selected answer, and stored
  explanation. Replies are rendered as Markdown, not parsed as structured grades.
- Test → select a level → **AI extra practice** generates three vocabulary,
  grammar, or reading questions with `POST /api/practice/generate`. Batch
  explanations follow the app's meaning language. The focused single-question
  endpoint currently returns English explanations; its tutor supports Korean.
- Multiple-choice scoring stays local. AI sessions do not affect ranked test
  results, XP, or SRS, and questions and conversations are discarded on exit.

AI-generated conversational follow-up questions appear inside the footer of
each AI reply. If a response includes `follow_up_questions`, the app uses them
directly. With the current reply-only API, it makes a separate tutor request for
up to three questions in the selected explanation language. The main reply is
shown immediately; suggestion failures leave it usable. Suggestion requests are
not added to conversation history. Sending text or tapping a follow-up returns
the transcript to the bottom; manually scrolling up releases that anchor.

The API receives up to six recent conversation messages (500 characters each)
and bounded lesson/question context. Requests use a 130-second timeout for the
backend's configurable model timeout and cold starts, show localized errors,
and allow manual retry while preserving typed questions. There is no automatic
retry that could duplicate model work. `GET /health` is available through
`JlptApiClient.health()`; it checks server reachability, not model readiness.

Live verification on 2026-10-18 confirmed health, both tutor endpoints, and
batch generation against the configured deployment. The optional focused
`/api/practice/question` endpoint returned HTTP 502 on two attempts. Its screen
handles this with an error and manual retry; that backend endpoint needs repair
before focused questions can be relied on. Batch extra practice remains available.

Override the address for staging or development:

```sh
flutter run --dart-define=JLPT_API_BASE_URL=https://your-api.example.com
```

Release builds require HTTPS. For local development, prefer an HTTPS tunnel;
Android emulators reach the Mac through `10.0.2.2` and physical devices need a
reachable LAN address or tunnel. Platform transport policies still apply to
HTTP debug overrides. The URL is public configuration; keep Ollama credentials
on the backend. The Flutter client never connects directly to Ollama.

Validate the integration without making live model calls:

```sh
flutter test test/api test/grammar_tutor_screen_test.dart test/grammar_qa_chat_screen_test.dart test/practice_test_screen_test.dart
```

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
