// Sudoku solver, generator, and logical difficulty grading.
export type Difficulty = 'easy' | 'medium' | 'hard' | 'expert' | 'custom';
export type Mode = 'challenge' | 'classic';
export type Source = 'collection' | 'generated';
export interface Puzzle {
  id: string; givens: number[]; solution: number[]; difficulty: Difficulty;
  source: Source; rating?: number;
}
export const all = 0b1111111110;
export const units = [
  ...Array.from({ length: 9 }, (_, r) => Array.from({ length: 9 }, (_, c) => r * 9 + c)),
  ...Array.from({ length: 9 }, (_, c) => Array.from({ length: 9 }, (_, r) => r * 9 + c)),
  ...Array.from({ length: 9 }, (_, b) => Array.from({ length: 9 }, (_, o) =>
    (Math.floor(b / 3) * 3 + Math.floor(o / 3)) * 9 + b % 3 * 3 + o % 3)),
];
export const peers = Array.from({ length: 81 }, (_, i) =>
  [...new Set(units.filter(u => u.includes(i)).flat())].filter(p => p !== i));
export const digits = (mask: number) => Array.from({ length: 9 }, (_, i) => i + 1).filter(d => mask & (1 << d));
export const candidates = (board: number[], i: number) => board[i] ? 0 :
  peers[i].reduce((mask, p) => mask & ~(1 << board[p]), all);
export function consistent(board: number[]): boolean {
  return Array.isArray(board) && board.length === 81 && board.every(v => Number.isInteger(v) && v >= 0 && v <= 9) &&
    units.every(u => { const values = u.map(i => board[i]).filter(Boolean); return new Set(values).size === values.length; });
}
export const complete = (board: number[]) => consistent(board) && !board.includes(0);
export function shuffled<T>(values: T[]): T[] {
  const result = [...values];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}
export function solutions(input: number[], limit = 2, randomized = false): number[][] {
  if (limit <= 0 || !consistent(input)) return [];
  const board = [...input], rows = Array(9).fill(0), cols = Array(9).fill(0), boxes = Array(9).fill(0);
  const box = (i: number) => Math.floor(i / 27) * 3 + Math.floor(i % 9 / 3);
  board.forEach((v, i) => { if (v) { rows[Math.floor(i / 9)] |= 1 << v; cols[i % 9] |= 1 << v; boxes[box(i)] |= 1 << v; } });
  const found: number[][] = [];
  let nodes = 0, exhausted = false;
  function search() {
    if (found.length >= limit || exhausted) return;
    if (++nodes > 100_000) { exhausted = true; return; }
    let best = -1, mask = 0, count = 10;
    for (let i = 0; i < 81; i++) {
      if (board[i]) continue;
      const possible = all & ~(rows[Math.floor(i / 9)] | cols[i % 9] | boxes[box(i)]);
      const size = digits(possible).length;
      if (!size) return;
      if (size < count) { best = i; mask = possible; count = size; if (size === 1) break; }
    }
    if (best < 0) { found.push([...board]); return; }
    const r = Math.floor(best / 9), c = best % 9, b = box(best);
    for (const d of randomized ? shuffled(digits(mask)) : digits(mask)) {
      const bit = 1 << d;
      board[best] = d; rows[r] |= bit; cols[c] |= bit; boxes[b] |= bit;
      search();
      rows[r] &= ~bit; cols[c] &= ~bit; boxes[b] &= ~bit;
      if (found.length >= limit || exhausted) break;
    }
    board[best] = 0;
  }
  search();
  return exhausted ? [] : found;
}
export function grade(input: number[]): Difficulty {
  const board = [...input], masks = board.map((_, i) => candidates(board, i));
  let level = 0;
  const place = (i: number, d: number) => { board[i] = d; masks[i] = 0; for (const p of peers[i]) masks[p] &= ~(1 << d); };
  while (board.includes(0)) {
    const single = masks.findIndex((m, i) => !board[i] && digits(m).length === 1);
    if (single >= 0) { place(single, digits(masks[single])[0]); continue; }
    let hidden: [number, number] | undefined;
    for (const unit of units) {
      for (let d = 1; d <= 9; d++) {
        const cells = unit.filter(i => masks[i] & (1 << d));
        if (cells.length === 1) { hidden = [cells[0], d]; break; }
      }
      if (hidden) break;
    }
    if (hidden) { level = Math.max(level, 1); place(...hidden); continue; }
    let changed = false;
    for (const a of units) {
      for (let d = 1; d <= 9; d++) {
        const cells = a.filter(i => masks[i] & (1 << d));
        if (cells.length < 2) continue;
        for (const b of units) {
          if (a === b || !cells.every(i => b.includes(i))) continue;
          for (const i of b) if (!a.includes(i) && (masks[i] & (1 << d))) { masks[i] &= ~(1 << d); changed = true; }
        }
      }
    }
    for (const unit of units) {
      const pairs = unit.filter(i => digits(masks[i]).length === 2);
      for (const i of pairs) {
        const pair = masks[i], twins = pairs.filter(j => masks[j] === pair);
        if (twins.length !== 2) continue;
        for (const j of unit) if (!twins.includes(j) && (masks[j] & pair)) { masks[j] &= ~pair; changed = true; }
      }
    }
    if (!changed) return 'expert';
    level = 2;
  }
  return (['easy', 'medium', 'hard'] as const)[level];
}
export function generate(difficulty: Difficulty, empty = 45): Puzzle {
  const deadline = Date.now() + 15_000;
  const target = difficulty === 'custom' ? Math.min(60, Math.max(20, Math.round(empty))) :
    { easy: 42, medium: 49, hard: 54, expert: 57 }[difficulty];
  for (let attempt = 0; attempt < 100 && Date.now() < deadline; attempt++) {
    const solution = solutions(Array(81).fill(0), 1, true)[0];
    if (!solution) continue;
    const board = [...solution];
    let removed = 0;
    for (const i of shuffled(Array.from({ length: 81 }, (_, i) => i))) {
      if (Date.now() >= deadline) break;
      const previous = board[i]; board[i] = 0;
      if (solutions(board).length === 1) removed++; else board[i] = previous;
      if (removed === target) break;
    }
    if (removed === target && (difficulty === 'custom' || grade(board) === difficulty)) {
      // randomUUID requires HTTPS; LAN previews still support getRandomValues.
      const id = typeof crypto.randomUUID === 'function' ? crypto.randomUUID() :
        Array.from(crypto.getRandomValues(new Uint8Array(16)), byte => byte.toString(16).padStart(2, '0')).join('');
      return { id, givens: board, solution, difficulty, source: 'generated' };
    }
  }
  throw new Error("Couldn't make a unique puzzle with those settings this time. Try again, choose fewer empty squares, or use the collection.");
}
