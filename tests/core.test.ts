import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { createGame, enter, erase, fillNotes, undo, redo, isOut, leastFilledDigit, validSave } from '../src/game/game';
import { all, candidates, complete, consistent, generate, grade, peers, solutions, type Puzzle } from '../src/game/sudoku';
import { darkAppearance, defaults, restorePreferences } from '../src/game/preferences';

const example = [...'530070000600195000098000060800060003400803001700020006060000280000419005000080079'].map(Number);
const puzzle = (): Puzzle => ({ id: 'test', givens: [...example], solution: solutions(example, 1)[0], difficulty: 'easy', source: 'collection' });
test('solver rejects invalid and ambiguous boards, and respects solution limits', () => {
  assert.equal(solutions(example).length, 1);
  const invalid = [...example]; invalid[2] = 5;
  assert.equal(solutions(invalid).length, 0);
  assert.equal(solutions(Array(81).fill(0)).length, 2);
  assert.equal(solutions(example, 0).length, 0);
  assert.equal(complete(solutions(example)[0]), true);
  assert.equal(consistent(Array(81).fill(10)), false);
  assert.equal(peers[40].length, 20);
});
test('Challenge rejects incorrect digits, strikes survive undo, and strike-out locks moves', () => {
  const g = createGame(puzzle());
  assert.equal(enter(g, 1, 2), 'strike'); assert.equal(g.board.values[2], 0);
  assert.equal(enter(g, 4, 2), 'changed'); undo(g);
  assert.equal(g.strikes, 1); assert.equal(g.board.values[2], 0);
  enter(g, 1, 2); enter(g, 1, 2);
  assert.equal(isOut(g), true); assert.equal(enter(g, 4, 2), 'ignored');
  g.mode = 'classic'; assert.equal(enter(g, 1, 2), 'changed'); assert.equal(g.strikes, 3);
});
test('unlimited Challenge still counts strikes without ending the game', () => {
  const g = createGame(puzzle(), 'challenge', 0);
  for (let i = 0; i < 12; i++) enter(g, 1, 2);
  assert.equal(g.strikes, 12); assert.equal(isOut(g), false);
});
test('manual notes, cleanup, and whole-board undo/redo preserve board state', () => {
  const g = createGame(puzzle());
  enter(g, 4, 3, true); enter(g, 4, 2, false, true);
  assert.equal(g.board.notes[3], 0); undo(g);
  assert.equal(g.board.notes[3], 1 << 4); assert.equal(g.board.values[2], 0);
  redo(g); assert.equal(g.board.notes[3], 0); assert.equal(g.board.values[2], 4);
  erase(g, 2); assert.equal(g.board.values[2], 0); undo(g); assert.equal(g.board.values[2], 4);
  assert.equal(enter(g, 3, 0), 'ignored'); assert.equal(enter(g, 10, 2), 'ignored');
  assert.equal(enter(g, 2, 2, true), 'ignored');
});
test('Fill Notes uses current board hypotheses, not solution, and is undoable', () => {
  const g = createGame(puzzle(), 'classic'); enter(g, 1, 2); fillNotes(g);
  assert.equal(g.board.notes[3], candidates(g.board.values, 3));
  assert.equal(g.board.notes[3] & (1 << 1), 0); undo(g);
  assert.deepEqual(g.board.notes, Array(81).fill(0));
});
test('Classic freely accepts hypotheses but only valid completion finishes', () => {
  const g = createGame(puzzle(), 'classic'); enter(g, 1, 2);
  assert.equal(g.strikes, 0); assert.equal(g.finished, false);
  erase(g, 2);
  g.puzzle.solution.forEach((d, i) => { if (!g.puzzle.givens[i]) enter(g, d, i); });
  assert.equal(g.finished, true); assert.equal(enter(g, 2, 2), 'ignored');
});
test('filled cells ignore number entry without strikes or history changes', () => {
  for (const mode of ['classic', 'challenge'] as const) {
    const g = createGame(puzzle(), mode);
    enter(g, 4, 2);
    const before = structuredClone(g);
    assert.equal(enter(g, 1, 2), 'ignored');
    assert.equal(enter(g, 4, 2), 'ignored');
    assert.equal(enter(g, 1, 2, true), 'ignored');
    assert.deepEqual(g, before);
    erase(g, 2);
    assert.equal(enter(g, 4, 2), 'changed');
  }
});
test('a completed digit ignores entries and notes until a copy is removed', () => {
  for (const mode of ['classic', 'challenge'] as const) {
    const g = createGame(puzzle(), mode);
    const missingFives = g.puzzle.solution.flatMap((digit, i) => digit === 5 && !g.board.values[i] ? [i] : []);
    for (const i of missingFives) assert.equal(enter(g, 5, i), 'changed');
    const before = structuredClone(g);
    const empty = g.board.values.indexOf(0);
    assert.equal(enter(g, 5, empty), 'ignored');
    assert.equal(enter(g, 5, empty, true), 'ignored');
    assert.deepEqual(g, before);
    undo(g);
    assert.equal(enter(g, 5, missingFives.at(-1)!), 'changed');
  }
});
test('starting digit uses the smallest count and randomizes only tied digits', () => {
  const values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 1, 2, 3, 4, 5, 6, 7];
  assert.equal(leastFilledDigit(values, () => 0), 8);
  assert.equal(leastFilledDigit(values, () => .99), 9);
  assert.equal(leastFilledDigit([...values, 8], () => .99), 9);
  assert.equal(leastFilledDigit([1, 2, 3, 4, 5, 6, 7, 8], () => 0), 9);
});
test('save validation rejects malformed board, notes, history, rules, and solution', () => {
  const g = createGame(puzzle()); assert.equal(validSave(g), true);
  for (const mutate of [
    (x: typeof g) => { x.board.values.pop(); },
    (x: typeof g) => { x.board.notes[0] = all + 1; },
    (x: typeof g) => { x.board.notes[0] = 2 ** 32; },
    (x: typeof g) => { x.puzzle.solution[0] = 0; },
    (x: typeof g) => { x.board.values[0] = 0; },
    (x: typeof g) => { x.elapsed = -1; },
    (x: typeof g) => { x.undoStack = Array(301).fill(x.board); },
    (x: typeof g) => { x.strikeLimit = 2; },
    (x: typeof g) => { x.finished = true; },
  ]) { const x = structuredClone(g); mutate(x); assert.equal(validSave(x), false); }
  assert.equal(validSave(null), false); assert.equal(validSave({}), false);
});
test('all 8,000 collection puzzles have unique solutions and retained ratings', () => {
  const text = readFileSync(new URL('../src/data/puzzles.txt', import.meta.url), 'utf8');
  const metadata = JSON.parse(readFileSync(new URL('../src/data/collection.json', import.meta.url), 'utf8'));
  assert.equal(metadata.count, 8000); assert.equal(metadata.bytes, Buffer.byteLength(text));
  assert.equal(metadata.sha256, createHash('sha256').update(text).digest('hex'));
  const counts: Record<string, number> = {};
  const ids = new Set<string>(), boards = new Set<string>();
  for (const line of text.trim().split('\n').filter(l => !l.startsWith('#'))) {
    const [difficulty, id, board, rating] = line.split(/\s+/);
    assert.ok(id); assert.ok(Number.isFinite(Number(rating)));
    assert.ok(!ids.has(id)); assert.ok(!boards.has(board)); ids.add(id); boards.add(board);
    assert.equal(solutions([...board].map(Number)).length, 1, id);
    counts[difficulty] = (counts[difficulty] || 0) + 1;
  }
  assert.deepEqual(counts, { easy: 2000, medium: 2000, hard: 2000, expert: 2000 });
});
test('custom generation returns exact empty counts and unique solutions', () => {
  for (const empty of [20, 45]) {
    const p = generate('custom', empty);
    assert.equal(p.givens.filter(v => !v).length, empty);
    assert.equal(solutions(p.givens).length, 1); assert.equal(complete(p.solution), true);
  }
});
test('generated difficulties match the logical grading definitions', () => {
  for (const level of ['easy', 'medium', 'hard', 'expert'] as const) {
    const p = generate(level); assert.equal(grade(p.givens), level); assert.equal(solutions(p.givens).length, 1);
  }
});
test('preferences are validated and overnight schedules use local clock correctly', () => {
  assert.equal(defaults.difficulty, 'medium');
  assert.equal(restorePreferences({ difficulty: 'hard' }).difficulty, 'hard');
  const p = restorePreferences({ theme: 'bad', showTimer: 'yes', strikeLimit: 2, customEmpty: 999, lightAt: -1 });
  assert.equal(p.theme, 'ink'); assert.equal(p.showTimer, false); assert.equal(p.strikeLimit, 2);
  for (const limit of [1, 2, 3, 4, 5]) assert.equal(restorePreferences({ strikeLimit: limit }).strikeLimit, limit);
  for (const limit of [0, 6, 10, -1, 2.5, '4']) assert.equal(restorePreferences({ strikeLimit: limit }).strikeLimit, 3);
  assert.equal(p.customEmpty, 60); assert.equal(p.lightAt, 0);
  const overnight = { ...defaults, appearance: 'scheduled' as const, lightAt: 1200, darkAt: 420 };
  assert.equal(darkAppearance(overnight, false, new Date(2026, 0, 1, 23)), false);
  assert.equal(darkAppearance(overnight, false, new Date(2026, 0, 1, 12)), true);
});
