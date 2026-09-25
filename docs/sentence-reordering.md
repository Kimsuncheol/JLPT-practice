# Sentence reordering data

`assets/data/jlpt_catalog.json` uses `meaningKo` and an `example` object with
`sentence`, `reading`, `translations`, `quizSentence`, and `answer`. The
migration adds `example.tokens` without changing those existing fields.

Tokens are ordered phrase tiles without punctuation. `tool/migrate_reorder_tokens.py`
uses fugashi (MeCab) with unidic-lite and joins trailing particles and
auxiliaries to the preceding tile. The Flutter app only reads the stored
tokens; it never segments Japanese text at runtime. An optional
`example.distractors` field is parsed but not used by the initial game.

To rerun the migration in a local virtual environment:

```sh
python3 -m venv .venv
.venv/bin/pip install -r tool/requirements-reorder.txt
.venv/bin/python -m unittest discover -s tool -p 'test_migrate_reorder_tokens.py'
.venv/bin/python tool/migrate_reorder_tokens.py
```

The script is idempotent. It skips existing tokens and logs examples it cannot
analyze. The migration run processed 8,395 examples without a fallback; 54
examples containing unknown MeCab morphemes have `tokens: null` and are listed
in `tool/reorder-migration-review.txt` for manual review. The game uses examples with 3–8 tiles and at least two
distinct tile texts. The existing app TTS provider currently uses
`FlutterTtsEngine`; the game calls its `TtsService` interface.
