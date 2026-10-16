# Free Sudoku data and credits

Research snapshot: October 12, 2026. GridZero does not need to buy puzzles.

## Shipped source: Grant McLean / Sudoku Exchange

Thank you to **Grant McLean** and [Sudoku Exchange](https://sudokuexchange.com/)
for the [Sudoku Exchange puzzle bank](https://github.com/grantm/sudoku-exchange-puzzle-bank).
Its dataset is explicitly dedicated to the public domain under the Unlicense.
The upstream README credits [Stephen Ostermiller's QQWing](https://github.com/stephenostermiller/qqwing)
for generation and [SudokuMonster's Sukaku Explainer](https://github.com/SudokuMonster/SukakuExplainer)
for ratings. GridZero imports their puzzle output, not their program code.
GridZero's optional runtime generator is independently implemented.

At pinned revision `d8c8ebaee0c08c412cfba96af1923dfa61c83317`, GitHub's file
metadata and the upstream 100-byte-record format show:

| File | Upstream records | GridZero level | Bundled |
|---|---:|---|---:|
| `easy.txt` | 100,000 | Easy | 2,000 |
| `medium.txt` | 352,643 | Medium | 2,000 |
| `hard.txt` | 321,592 | Hard | 2,000 |
| `diabolical.txt` | 119,681 | Expert | 2,000 |
| **Total** | **893,916** | | **8,000** |

These are record counts, not a claim that all upstream boards are distinct under
Sudoku symmetries. The bundled selection is checked for duplicate IDs/exact boards.
The earlier 400-board bundle was an intentional importer limit of 100 per bucket,
not a limitation of the free source. Expansion preserves those original IDs.

## Reproducibility and licenses

```sh
python3 tools/import_puzzles.py
# Default: 2,000 per difficulty. Larger selections are explicitly supported:
# python3 tools/import_puzzles.py --per-difficulty 5000
```

The importer reads a pinned upstream commit, verifies 81 digits, the upstream
SHA-1-derived identifier, published rating bucket, duplicate IDs/boards, and
exactly one solution with a bounded independent solver. It verifies the entire
selection before replacing generated files.

The canonical text resource is **840,000 bytes (840 KB decimal)**. All platforms
use it directly. `Sources/GridZeroCore/Resources/collection.json` records counts,
revision, selection, source, license, byte size, and SHA-256:

`322af3981362ac873c3f8a9f930c47e56482f6d3aaa664309b9ffd64e796863d`

The upstream license is retained in
`Sources/GridZeroCore/Resources/Puzzle-LICENSE.txt`; the web copy with source
credit is `site/public/assets/Puzzle-LICENSE.txt`. Swift packages the resource;
Android references that directory as assets; Astro imports it at build time.
Bundle size is a tradeoff we accept for offline access, not a 400-board cap.

Credits are available on the website `/credits/`, linked from the homepage/footer
and web Settings, and in both native Settings screens. App code/original artwork
are MIT; the puzzle bank is public domain. Do not call all dependencies MIT.

## Other free data considered, not shipped

[Tdoku](https://github.com/t-dillon/tdoku) provides solver/generator code and
benchmark datasets, including a roughly 49,000-board 17-clue collection and very
hard forum puzzles. It is useful for solver research, but the repository code's
BSD-2-Clause license is not by itself proof of permission/provenance for every
third-party dataset in the archive. Those collections also are not a balanced
four-level, published-rating player collection. **No Tdoku/Royle/forum/Kaggle
records or solver code are imported into GridZero.**

We prefer the much larger explicitly public-domain Sudoku Exchange bank over
mixing scraped puzzles or datasets with uncertain per-source rights. Any later
source needs its own license, attribution, stable IDs, independent uniqueness
validation, difficulty mapping, and manifest—not just a "free download" label.

## Expansion decision

Current release: 8,000 bundled, offline everywhere. More records can be imported
without a server. A static, explicit-download pack protocol is specified in
[SPEC §9](SPEC.md#9-future-static-puzzle-packs--design-only-not-implemented), but
there is **no download API or native download feature today**. Do not advertise
that roadmap as shipped functionality.
