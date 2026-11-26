#!/usr/bin/env python3
"""Import a pinned, reproducible, uniqueness-checked public-domain collection.

Standard library only. Network access is build-time tooling, never app behavior.
"""
import hashlib
import argparse
import json
import pathlib
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
REVISION = "d8c8ebaee0c08c412cfba96af1923dfa61c83317"
BASE = f"https://raw.githubusercontent.com/grantm/sudoku-exchange-puzzle-bank/{REVISION}/"
UPSTREAM_COUNTS = {"easy": 100000, "medium": 352643, "hard": 321592, "expert": 119681}

def count_solutions(board):
    if len(board) != 81 or any(not 0 <= v <= 9 for v in board):
        return 0
    rows, columns, boxes = [0] * 9, [0] * 9, [0] * 9
    for i, value in enumerate(board):
        if not value:
            continue
        r, c, b = i // 9, i % 9, i // 27 * 3 + i % 9 // 3
        bit = 1 << value
        if (rows[r] | columns[c] | boxes[b]) & bit:
            return 0
        rows[r] |= bit; columns[c] |= bit; boxes[b] |= bit
    nodes = 0
    def search():
        nonlocal nodes
        nodes += 1
        if nodes > 100000:
            raise ValueError("Uniqueness verification exceeded the solver budget")
        best, mask, size = -1, 0, 10
        for i, value in enumerate(board):
            if value:
                continue
            possible = 1022 & ~(rows[i // 9] | columns[i % 9] | boxes[i // 27 * 3 + i % 9 // 3])
            count = bin(possible).count("1")
            if not count:
                return 0
            if count < size:
                best, mask, size = i, possible, count
                if size == 1:
                    break
        if best < 0:
            return 1
        r, c, b = best // 9, best % 9, best // 27 * 3 + best % 9 // 3
        total = 0
        while mask:
            bit = mask & -mask; mask &= ~bit
            board[best] = bit.bit_length() - 1
            rows[r] |= bit; columns[c] |= bit; boxes[b] |= bit
            total += search()
            rows[r] &= ~bit; columns[c] &= ~bit; boxes[b] &= ~bit
            if total >= 2:
                break
        board[best] = 0
        return min(2, total)
    return search()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--per-difficulty", type=int, default=2000)
    args = parser.parse_args()
    if not 1 <= args.per_difficulty <= min(UPSTREAM_COUNTS.values()):
        parser.error("per-difficulty must be between 1 and 100000")
    records = []
    identifiers, boards = set(), set()
    for difficulty, filename in [("easy", "easy.txt"), ("medium", "medium.txt"),
                                  ("hard", "hard.txt"), ("expert", "diabolical.txt")]:
        with urllib.request.urlopen(BASE + filename, timeout=60) as response:
            for _ in range(args.per_difficulty):
                line = response.readline().decode("ascii")
                identifier, digits, rating = line.split()
                if len(digits) != 81 or not digits.isdigit() or not hashlib.sha1(digits.encode()).hexdigest().startswith(identifier):
                    raise ValueError(f"Malformed upstream record: {identifier}")
                if identifier in identifiers or digits in boards:
                    raise ValueError(f"Duplicate upstream record: {identifier}")
                if count_solutions([int(d) for d in digits]) != 1:
                    raise ValueError(f"Puzzle is not uniquely solvable: {identifier}")
                number = float(rating)
                if not {"easy": number < 1.5, "medium": 1.5 <= number < 2.5, "hard": 2.5 <= number < 5, "expert": number >= 5}[difficulty]:
                    raise ValueError(f"Unexpected difficulty rating: {identifier}")
                identifiers.add(identifier); boards.add(digits)
                records.append(f"{difficulty} {identifier} {digits} {rating}\n")
        print(f"Validated {args.per_difficulty} {difficulty} puzzles", flush=True)
    destination = ROOT / "src/data/puzzles.txt"
    data = "".join(records).encode("ascii")
    metadata = {
        "schemaVersion": 1, "collectionVersion": f"sudoku-exchange-{len(records)}-v1",
        "source": "Grant McLean / Sudoku Exchange puzzle bank",
        "sourceUrl": "https://github.com/grantm/sudoku-exchange-puzzle-bank",
        "revision": REVISION, "license": "Unlicense (public domain)",
        "generatedWith": "QQWing", "ratedWith": "Sukaku Explainer",
        "selection": f"First {args.per_difficulty} records from each pinned upstream file; original IDs preserved",
        "count": len(records), "perDifficulty": {d: args.per_difficulty for d in UPSTREAM_COUNTS},
        "upstreamCounts": UPSTREAM_COUNTS, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
    }
    # Verify every record before replacing the generated resources.
    for path, content in [(destination, data), (destination.with_name("collection.json"), (json.dumps(metadata, indent=2) + "\n").encode())]:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
            temporary.write(content); name = pathlib.Path(temporary.name)
        name.chmod(0o644); name.replace(path)
    print(f"Wrote {len(records)} puzzles ({destination.stat().st_size:,} bytes)")

if __name__ == "__main__":
    main()
