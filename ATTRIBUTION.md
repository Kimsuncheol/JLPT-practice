# Data attribution

The ranked JLPT vocabulary and grammar catalogs are imported from
[tristcoil/hanabira.org](https://github.com/tristcoil/hanabira.org), which is
distributed under the MIT License.

Copyright (c) 2024 coil

Hanabira's vocabulary filenames and audio paths identify the vocabulary data
as Tanos-derived. JLPT does not publish an official vocabulary or grammar list,
so ranks in this app reflect the source dataset rather than an official syllabus.

The source grammar examples are preserved. Vocabulary examples and Korean
translations are generated for this app where complete source examples are not
available. Korean grammar explanations and example meanings are machine
translated from the source English content. `assets/data/vocabulary.json`
retains a small hand-authored subset.

## JLPT mock-exam structure

`assets/data/jlpt_ranked_mock_questions.csv` organizes the app's mock bank by
JLPT level, official item-type part, and an internal variant rank. The item-type
blueprint is based on the JLPT's public
[Composition of Test Sections and Items](https://www.jlpt.jp/e/guideline/testsections.html)
and level-specific “Purposes of test items” documents.

The blueprint is used only to match the published structure. It does not claim
to reproduce a current live exam or its undisclosed item counts. Official
practice reference questions remain only in the legacy project bank; they are
not copied into the live ranked bank. Questions marked `legacy_app_authored` or
`new_app_authored` are app practice content. The legacy file
`assets/data/jlpt_test_problems_2021_2025.csv` remains unchanged as a reference
and is no longer loaded by the app's mock-test flow.
