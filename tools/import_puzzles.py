#!/usr/bin/env python3
"""Import a small, reproducible, uniqueness-checked public-domain collection.

Standard library only. Network access is build-time tooling, never app behavior.
"""
import hashlib
import pathlib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/grantm/sudoku-exchange-puzzle-bank/master/"
UNITS = ([[r * 9 + c for c in range(9)] for r in range(9)] +
         [[r * 9 + c for r in range(9)] for c in range(9)] +
         [[(b // 3 * 3 + i // 3) * 9 + b % 3 * 3 + i % 3 for i in range(9)] for b in range(9)])
PEERS = [set(sum([u for u in UNITS if i in u], [])) - {i} for i in range(81)]

def count_solutions(board):
    for unit in UNITS:
        values = [board[i] for i in unit if board[i]]
        if len(values) != len(set(values)):
            return 0
    def search():
        choices = [(set(range(1, 10)) - {board[p] for p in PEERS[i]}, i)
                   for i in range(81) if not board[i]]
        if not choices:
            return 1
        options, index = min(choices, key=lambda pair: len(pair[0]))
        total = 0
        for digit in options:
            board[index] = digit
            total += search()
            if total >= 2:
                break
        board[index] = 0
        return min(2, total)
    return search()

def main():
    records = []
    for difficulty, filename in [("easy", "easy.txt"), ("medium", "medium.txt"),
                                  ("hard", "hard.txt"), ("expert", "diabolical.txt")]:
        with urllib.request.urlopen(BASE + filename) as response:
            for _ in range(100):
                line = response.readline().decode("ascii")
                identifier, digits, rating = line.split()
                assert len(digits) == 81 and digits.isdigit()
                assert hashlib.sha1(digits.encode()).hexdigest().startswith(identifier)
                assert count_solutions([int(d) for d in digits]) == 1, identifier
                records.append(f"{difficulty} {identifier} {digits} {rating}\n")
        print(f"Validated 100 {difficulty} puzzles")
    destination = ROOT / "Sources/GridZeroCore/Resources/puzzles.txt"
    destination.write_text("".join(records), encoding="ascii")
    print(f"Wrote {len(records)} puzzles ({destination.stat().st_size:,} bytes)")

if __name__ == "__main__":
    main()
