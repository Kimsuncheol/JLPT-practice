# JLPT study privacy baseline

JLPT study uses Firebase Authentication and Firestore to synchronize study
preferences, quiz and practice-test history, review progress, grammar progress,
study sessions, streaks, XP, and unlocks. Use without registration remains
available through an anonymous Firebase account. Users may optionally protect
and restore their progress with email/password, Google, or Apple sign-in.

The development build runs local-first and leaves advertisements disabled.
When ads are enabled, Google Mobile Ads and the required consent flow must be
configured for the distribution region. Store privacy disclosures, a hosted
privacy-policy URL, consent testing, data-deletion instructions, and
`app-ads.txt` remain release tasks.

Clearing app storage or uninstalling the app can remove locally held learning
history and access to an unlinked anonymous account. Permanent accounts can be
deleted with their synchronized data from the in-app account screen.

AI tutor and extra-practice features send bounded lesson/question context,
learner messages, and up to six recent messages to the configured JLPT FastAPI
service (hosted on Render by default), which uses its configured Ollama model
provider. The app sends no Firebase account identifier in these requests and
stores neither chat content nor AI-generated practice sessions. Closing a chat
clears its in-memory conversation. Normal study progress remains subject to
the Firebase synchronization described above. The backend is configured without
application-level conversation persistence or content logging; hosting and
model providers process requests under their own policies.
