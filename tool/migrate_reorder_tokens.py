"""One-time MeCab migration for ordered sentence-reordering tiles.

Run: .venv/bin/python tool/migrate_reorder_tokens.py
The script only adds example.tokens. Review the resulting catalog diff before
shipping; entries with failed analysis remain ineligible.
"""

import argparse
import json
import logging
import re
from dataclasses import dataclass
from pathlib import Path

PUNCTUATION = set("。、！？!?，,．.：:；;「」『』（）()・…〜～\n\r\t ")


@dataclass(frozen=True)
class Morpheme:
    surface: str
    part_of_speech: str


def merge_particles_into_tokens(raw_morphemes: list[Morpheme]) -> list[str]:
    """Attach particles and auxiliaries to the preceding tile; discard punctuation."""
    tokens: list[str] = []
    for morpheme in raw_morphemes:
        surface = "".join(c for c in morpheme.surface if c not in PUNCTUATION)
        if not surface:
            continue
        if morpheme.part_of_speech in {"助詞", "助動詞"} and tokens:
            tokens[-1] += surface
        else:
            tokens.append(surface)
    return tokens


def normalized(sentence: str) -> str:
    return "".join(c for c in sentence if c not in PUNCTUATION)


def migrate(catalog_path: Path, *, rebuild: bool = False) -> dict[str, int]:
    from fugashi import Tagger  # analyzer stays an offline-only dependency

    tagger = Tagger()
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    counts = {"migrated": 0, "skipped_no_example": 0,
              "skipped_already_has_tokens": 0, "fallback_used": 0,
              "analysis_failed": 0}
    for index, entry in enumerate(catalog):
        example = entry.get("example")
        if not isinstance(example, dict) or not isinstance(example.get("sentence"), str) or not example["sentence"].strip():
            counts["skipped_no_example"] += 1
            logging.info("No example: %s", index)
            continue
        if example.get("tokens") is not None and not rebuild:
            counts["skipped_already_has_tokens"] += 1
            continue
        sentence = example["sentence"]
        try:
            analyzed = list(tagger(sentence))
            unknown = [word.surface for word in analyzed if word.is_unk]
            if unknown:
                raise ValueError(f"unknown morphemes: {unknown}")
            raw = [Morpheme(word.surface, word.feature.pos1) for word in analyzed]
            tokens = merge_particles_into_tokens(raw)
            if not tokens or "".join(tokens) != normalized(sentence):
                raise ValueError("tokens do not reconstruct the sentence")
            example["tokens"] = tokens
            counts["migrated"] += 1
        except Exception as exc:
            example["tokens"] = None
            counts["analysis_failed"] += 1
            logging.warning("Review %s %s: %s", index, entry.get("word"), exc)
    pretty = json.dumps(catalog, ensure_ascii=False, indent=4)
    # Keep each tile list on one line so the large catalog stays reviewable.
    token_array = re.compile(r'(?m)^            "tokens": \[\n((?:                .*\n)+)            \]')
    pretty = token_array.sub(
        lambda match: '            "tokens": ' + json.dumps(
            json.loads('[' + match.group(1) + ']'), ensure_ascii=False
        ),
        pretty,
    )
    catalog_path.write_text(pretty + "\n", encoding="utf-8")
    return counts


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("catalog", nargs="?", type=Path,
                        default=Path("assets/data/jlpt_catalog.json"))
    parser.add_argument("--rebuild", action="store_true",
                        help="Reanalyze existing tokens after a migration-rule change")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    for key, value in migrate(args.catalog, rebuild=args.rebuild).items():
        print(f"{key}: {value}")
