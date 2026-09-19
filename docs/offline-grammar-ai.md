# Offline grammar AI

The grammar tutor uses local llama.cpp inference. It does not call Firebase AI
or silently fall back to the cloud. Separate conversation/test AI features still
use their existing online services. Ordinary grammar lessons and quizzes do not
need a model.

## User flow

Every `/grammar/tutor/:id` route, including Recent Study and deep links, enters
the setup gate. Users choose a compatible model and explicitly download it.
Settings → Offline grammar AI supports model selection, download/resume,
Wi-Fi-only downloads, load testing, and deletion. Partial downloads survive
restarts. Downloads pause on backgrounding or loss of Wi-Fi when restricted.

The local model must pass its pinned size and SHA-256 checks, then load and
generate a short response before the tutor opens. Inference runs on a separate
native worker; the main Flutter isolate stays responsive. Models stay loaded
within a tutor session and unload on exit, backgrounding, or memory/thermal
pressure. The current CPU runtime queues disposal after an in-flight native
operation; it does not support immediate token-level cancellation. Interrupted
responses are discarded. Output is capped at 320 tokens and context at 2048.

## Model manifest and limits

`offline_ai_model.dart` contains immutable source revisions, actual byte sizes,
and SHA-256 values for Bartowski's Q4_K_M conversions. Updating a model requires
a reviewed app release with a new ID/revision/hash, not an unverified remote
configuration value. No Hugging Face access token is embedded in the app.

| Model | Download bytes | Physical RAM eligibility | Additional load budget |
| --- | ---: | ---: | ---: |
| Llama 3.2 1B Instruct Q4_K_M | 807,694,464 | 3.5 GiB | 1.5 GiB |
| Llama 3.2 3B Instruct Q4_K_M | 2,019,377,696 | 5.5 GiB | 3 GiB |

These are provisional heuristics, **not proven safe device tiers**. The slightly
lower physical thresholds account for advertised RAM versus OS-visible memory.
Android reports available memory minus its low-memory threshold. iOS uses
`os_proc_available_memory()` as current per-process headroom, not free system
RAM. Capacity is rechecked after verification, before load, and before inference.
Low-memory or hot devices are blocked. The OS can still kill a process under
pressure; a successful test load cannot guarantee future allocations.

Space required is the remaining download plus 256 MiB headroom. GGUF is streamed
directly to `.part` and atomically renamed after verification, so no extraction
or second model-sized copy is needed. Model files use Android's no-backup
directory and iOS Application Support with backup exclusion. Disk capacity stays
on-device; the iOS privacy manifest declares the download-space API reason.

## Feedback quality

The model receives the target grammar, meaning, formation, two examples, and a
sentence limited to 300 characters. Learner text is encoded as data in a user
message. Returned JSON is validated for complete fields, range and consistent
score/correctness. Invalid output shows a retry error and never updates mastery.

Japanese and Korean are not among Llama 3.2's officially supported eight
languages. This integration is marked experimental; it is not evidence that
either model can reliably grade JLPT grammar. Before production rollout, use a
teacher-reviewed fixed set covering N5–N1, correct and incorrect sentences,
missing target grammar, naturalness, Korean/English explanations, and prompts
that try to override the evaluator. Measure false rejections, false acceptance,
correction quality, JSON failures, first-response latency, peak memory and heat
on real low/mid/high-tier Android and iOS hardware. Do not assume 3B is accurate
merely because it is larger. No model fine-tuning is part of this change.

## Verification

Run `flutter test test/offline_ai_test.dart` for download recovery, checksums,
capacity, parser, lifecycle and setup UI coverage. The other grammar tests verify
the lesson flow remains usable without downloading model weights in unit tests.

`test/offline_ai_native_test.dart` is opt-in using `JLPT_AI_MODEL_PATH` and
`JLPT_AI_LIBRARY_PATH` Dart defines. It verifies the pinned 1B file, loads the
actual native library, makes two requests and disposes the runtime. It is a
runtime smoke test, not a grammar-accuracy or phone-performance benchmark.

Model attribution and the full Meta license are in `assets/offline_ai/` and
accessible from the setup screen. The runtime dependency is pinned to 0.7.3;
published mobile artifacts currently use CPU inference.
