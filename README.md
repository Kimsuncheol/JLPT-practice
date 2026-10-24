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

Vocabulary example generation (`tool/generate_jlpt_examples.dart`) requires
`sentence_furigana`, for example `{旅行|りょこう}から{帰|かえ}った。`.
The generator rejects missing readings, unannotated kanji, and annotations that
change the written sentence before saving. Study cards render readings above
their kanji, respecting **Hide reading**. Older examples with a full kana reading
also use this layout when the reading aligns with the sentence.

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

## Daily Japanese lessons

Home shows the newest ready expression from the Japanese lesson archive, with
its publication date and Korean meaning. It is labelled **Today’s expression**
only when its publication date matches the device’s current date; otherwise it
shows **Latest expression**. Tap the expression to open its lesson, or use
**Browse lessons** to search Japanese/Korean text and browse ten lessons per page.
Lesson detail separates the main expression from a conversation panel with
alternating dialogue bubbles. Tap Japanese text to play TTS and tap the same text
again to stop. It includes Korean notes, furigana where readings align, and **Ask AI Tutor** for
an expression or example. Tutor explanations follow the selected meaning language.

The read-only source defaults to `https://japanese-scraper.onrender.com` and can
be overridden using `--dart-define=JAPANESE_LESSON_API_BASE_URL=https://...`.
It uses `GET /api/articles?status=ready&page=...&q=...` and
`GET /api/articles/<id>`. Render cold starts allow a 90-second timeout with
manual retry. Up to 30 responses are saved locally: saved content appears while
refreshing and remains usable when refresh fails. Browsed list pages also supply
cached lesson details, including after an app restart. Uncached pages need a
network connection; TTS availability depends on the configured speech engine.
Source transcription uncertainty and a selectable original article URL are shown.
These supplementary lessons have no JLPT classification and do not alter SRS,
XP, ranked practice, or the bundled vocabulary/grammar catalogs.

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
  synonyms, and usage contrasts. Past-exam examples, approximate difficulty,
  and study notice sections are omitted, including when older servers return
  their metadata. Exactly three follow-up questions
  arrive with the explanation in one call and appear in its message footer.
  Tap a question or type in the composer to continue through `/api/tutor/chat`
  in the same conversation with bounded word context and recent history.
  Errors keep the conversation and allow manual retry. Explanations and chats
  stay in memory and are discarded when the screen closes. This requires a
  backend deployment that includes `/api/words/explain`.
  Generated examples accept `sentence_furigana` using `{kanji|hiragana}` markup;
  chat renders these readings above the kanji with the same widget as study
  cards. Older backend responses with a full kana `reading` are aligned when
  possible. Usage contrasts require `natural_example_furigana` and
  `unnatural_example_furigana`, rendered above the corresponding kanji as well.
  Tutor follow-ups can use the same inline markup in reply Markdown.
- Grammar → AI menu → **Grammar Tutor** automatically calls `POST /api/tutor/chat`
  with the selected lesson context on opening. A hidden initial request asks for
  a detailed explanation of meaning, formation, usage, nuance, common mistakes,
  comparisons, and two examples with furigana and translations. Three generated
  follow-up questions arrive with the reply. Grammar Tutor requests
  `structured_examples: true`: the service returns validated `examples` with
  written Japanese, complete `sentence_furigana`, and a separate translation.
  Placement markers in the explanation become whole-sentence furigana widgets,
  matching the grammar study screen, with translations below. This applies to
  initial and later replies. Incomplete readings or missing examples show the
  normal retryable response error instead of partially annotated text. Older
  servers must be deployed with this contract before using the updated app.
  Lesson context also includes annotated examples. The initial suggestion-chip
  container is omitted. **Practise with AI** opens a guided conversation; its quiz
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
