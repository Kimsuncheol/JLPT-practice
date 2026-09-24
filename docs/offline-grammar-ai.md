# Offline grammar AI

The grammar tutor uses Flutter Gemma with the LiteRT-LM engine for local
inference. It does not call Firebase AI or fall back to the cloud. Other
conversation and test AI features still use their existing online services.
Ordinary grammar lessons and quizzes do not require a model.

## User flow

Every `/grammar/tutor/:id` route enters the setup gate. Users choose a
compatible model and explicitly download it. Settings → Offline grammar AI
supports model selection, download/resume, Wi-Fi-only downloads, load testing,
and deletion. Partial downloads survive restarts. Downloads pause on
backgrounding or loss of Wi-Fi when restricted.

The local model must pass its pinned size and SHA-256 checks, then load and
generate a short response before the tutor opens. Flutter Gemma uses a native
LiteRT-LM runtime. Models unload on exit, backgrounding, or memory/thermal
pressure. An in-flight response can finish before disposal; interrupted
responses are discarded. Output is capped at 320 tokens and context at 2048.

## Model manifest and limits

`offline_ai_model.dart` contains immutable source revisions, byte sizes, and
SHA-256 values for the LiteRT Community's Gemma 4 `.litertlm` packages.
Updating a model requires a reviewed app release with a new ID/revision/hash.
No Hugging Face access token is embedded in the app.

| Model | Download bytes | Physical RAM eligibility | Additional load budget |
| --- | ---: | ---: | ---: |
| Gemma 4 E2B Instruct | 2,588,147,712 | 4 GiB | 2 GiB |
| Gemma 4 E4B Instruct | 3,659,530,240 | 6 GiB | 3 GiB |

These are provisional heuristics, not proven safe device tiers. Android
reports available memory minus its low-memory threshold. iOS uses
`os_proc_available_memory()` as current per-process headroom. Capacity is
rechecked before load and inference. Low-memory or hot devices are blocked.

Space required is the remaining download plus 256 MiB headroom. The model is
streamed directly to `.part` and atomically renamed after verification.
Flutter Gemma registers the verified file in place without a second copy.
Model files use Android's no-backup directory and iOS Application Support with
backup exclusion.

## Feedback quality

The model receives the target grammar, meaning, formation, two examples, and a
sentence limited to 300 characters. Learner text is encoded as data in a user
message. Returned JSON is validated for complete fields, range, and consistent
score/correctness. Invalid output shows a retry error and never updates mastery.

This integration is experimental. Before production rollout, use a
teacher-reviewed fixed set covering N5–N1, correct and incorrect sentences,
missing target grammar, naturalness, Korean/English explanations, and prompts
that try to override the evaluator. Measure grading errors, JSON failures,
latency, peak memory, and heat on real Android and iOS hardware. No model
fine-tuning is part of this change.

## Verification

Run `flutter test test/offline_ai_test.dart` for download recovery, checksums,
capacity, parser, lifecycle, and setup UI coverage.

`test/offline_ai_native_test.dart` is opt-in using `JLPT_AI_MODEL_PATH` Dart
define. It verifies the pinned E2B file, loads the Flutter Gemma runtime, makes
two requests, and disposes the model. It is a runtime smoke test, not a
grammar-accuracy or phone-performance benchmark.

Model attribution and the Apache 2.0 license are in `assets/offline_ai/` and
accessible from the setup screen. Flutter Gemma runs the LiteRT-LM CPU backend
in this integration.
