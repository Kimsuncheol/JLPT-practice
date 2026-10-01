"""Annotate example kanji runs using existing readings and offline MeCab.

Run: .venv/bin/python tool/migrate_sentence_furigana.py
Kana anchors preserve existing readings when they align. Inconsistent examples
use dictionary readings from sentence analysis. Only sentence_furigana fields
are updated; written sentences and vocabulary word readings stay intact.
"""

import functools
import json
import re
from pathlib import Path

from fugashi import Tagger

KANJI = re.compile(r"[㐀-䶿一-鿿々〆]+")
MARKUP = re.compile(r"\{([^|}]+)\|([^}]+)\}")
TAGGER = Tagger()


def normalize(text):
    return "".join(
        chr(ord(char) - 96) if "ァ" <= char <= "ヶ" else char
        for char in text if not char.isspace()
    )


@functools.lru_cache(None)
def dictionary_reading(text):
    return normalize("".join(
        word.feature.kana or word.surface for word in TAGGER(text)
    ))


@functools.lru_cache(None)
def edit_distance(first, second):
    row = list(range(len(second) + 1))
    for index, char in enumerate(first):
        next_row = [index + 1]
        for other_index, other in enumerate(second):
            next_row.append(min(
                next_row[-1] + 1,
                row[other_index + 1] + 1,
                row[other_index] + (char != other),
            ))
        row = next_row
    return row[-1]


def align(sentence, reading):
    """Match literal kana anchors and allocate readings to kanji-only runs."""
    runs = []
    cursor = 0
    for match in KANJI.finditer(sentence):
        if match.start() > cursor:
            runs.append((False, sentence[cursor:match.start()]))
        runs.append((True, match.group()))
        cursor = match.end()
    if cursor < len(sentence):
        runs.append((False, sentence[cursor:]))
    reading = "".join(char for char in reading if not char.isspace())
    normalized = normalize(reading)

    @functools.lru_cache(None)
    def solve(index, offset):
        if index == len(runs):
            return (0, []) if offset == len(reading) else None
        has_ruby, base = runs[index]
        if not has_ruby:
            plain = normalize(base)
            if not normalized.startswith(plain, offset):
                return None
            tail = solve(index + 1, offset + len(plain))
            return (tail[0], [(base, None)] + tail[1]) if tail else None
        best = None
        limit = min(len(reading), offset + max(12, len(base) * 6))
        for end in range(offset + 1, limit + 1):
            tail = solve(index + 1, end)
            if tail:
                score = tail[0] + edit_distance(
                    normalized[offset:end], dictionary_reading(base)
                )
                if best is None or score < best[0]:
                    best = (score, [(base, reading[offset:end])] + tail[1])
        return best

    return solve(0, 0)


def render(segments):
    return "".join(
        f"{{{base}|{ruby}}}" if ruby else base for base, ruby in segments
    )


def annotate(sentence, reading):
    if MARKUP.search(reading):
        return reading, False
    result = align(sentence, reading)
    if result is not None:
        return render(result[1]), False

    # Keep the exact written sentence, including whitespace and punctuation.
    pieces = []
    cursor = 0
    for word in TAGGER(sentence):
        start = sentence.index(word.surface, cursor)
        pieces.append(sentence[cursor:start])
        cursor = start + len(word.surface)
        surface = word.surface
        if not KANJI.search(surface):
            pieces.append(surface)
            continue
        result = align(surface, normalize(word.feature.kana or surface))
        if result:
            pieces.append(render(result[1]))
        elif surface in ("ヶ月", "ヵ月"):
            # These counter symbols are katakana; annotate only 月.
            pieces.append(surface[0] + "{月|げつ}")
        else:
            pieces.append(KANJI.sub(
                lambda match: f"{{{match.group()}|{dictionary_reading(match.group())}}}",
                surface,
            ))
    pieces.append(sentence[cursor:])
    return "".join(pieces), True


def migrate(path):
    raw = path.read_text()
    entries = json.loads(raw)
    replacements = []
    fallbacks = []
    for entry in entries:
        example = entry["example"]
        reading = example.get("sentence_furigana", example.get("reading", ""))
        markup, fallback = annotate(example["sentence"], reading)
        assert MARKUP.sub(lambda match: match[1], markup) == example["sentence"]
        replacements.append(markup)
        if fallback:
            fallbacks.append(entry["word"])
    values = iter(replacements)
    if all("sentence_furigana" in entry["example"] for entry in entries):
        raw = re.sub(
            r'(?m)^(\s*"sentence_furigana": ).*$',
            lambda match: match[1] + json.dumps(next(values), ensure_ascii=False) + ",",
            raw,
        )
    else:
        assert all("sentence_furigana" not in entry["example"] for entry in entries)
        raw = re.sub(
            r'(?m)^(      "reading": .*\n)',
            lambda match: match[1] + '      "sentence_furigana": '
            + json.dumps(next(values), ensure_ascii=False) + ",\n",
            raw,
        )
    assert next(values, None) is None
    path.write_text(raw)
    print(f"{path}: {len(replacements)} examples, {len(fallbacks)} dictionary fallbacks")


if __name__ == "__main__":
    for path in map(Path, [
        "assets/data/jlpt_catalog.json", "assets/data/vocabulary.json",
    ]):
        migrate(path)
