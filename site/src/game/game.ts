import { all, candidates, complete, consistent, peers, type Mode, type Puzzle } from './sudoku';
export interface Board { values: number[]; notes: number[]; }
export interface Game {
  puzzle: Puzzle; mode: Mode; strikeLimit: number; strikes: number; board: Board;
  undoStack: Board[]; redoStack: Board[]; elapsed: number; finished: boolean;
}
export type Result = 'ignored' | 'changed' | 'strike' | 'completed';
export const createGame = (puzzle: Puzzle, mode: Mode = 'challenge', strikeLimit = 3): Game => ({
  puzzle, mode, strikeLimit, strikes: 0, board: { values: [...puzzle.givens], notes: Array(81).fill(0) },
  undoStack: [], redoStack: [], elapsed: 0, finished: false,
});
export const isOut = (g: Game) => g.mode === 'challenge' && g.strikeLimit > 0 && g.strikes >= g.strikeLimit && !g.finished;
export const locked = (g: Game) => g.finished || isOut(g);
export const canUndo = (g: Game) => !locked(g) && g.undoStack.length > 0;
export const canRedo = (g: Game) => !locked(g) && g.redoStack.length > 0;
const copy = (b: Board): Board => ({ values: [...b.values], notes: [...b.notes] });
function remember(g: Game) { g.undoStack.push(copy(g.board)); g.undoStack = g.undoStack.slice(-300); g.redoStack = []; }
export function enter(g: Game, digit: number, i: number, pencil = false, cleanup = false): Result {
  if (!Number.isInteger(i) || i < 0 || i >= 81 || !Number.isInteger(digit) || digit < 1 || digit > 9 || g.puzzle.givens[i] || locked(g)) return 'ignored';
  if (pencil) {
    if (g.board.values[i]) return 'ignored';
    remember(g); g.board.notes[i] ^= 1 << digit; return 'changed';
  }
  if (g.board.values[i] === digit) return 'ignored';
  if (g.mode === 'challenge' && g.puzzle.solution[i] !== digit) { g.strikes++; return 'strike'; }
  remember(g); g.board.values[i] = digit; g.board.notes[i] = 0;
  if (cleanup) for (const p of peers[i]) g.board.notes[p] &= ~(1 << digit);
  g.finished = complete(g.board.values);
  return g.finished ? 'completed' : 'changed';
}
export function erase(g: Game, i: number) {
  if (i < 0 || i >= 81 || g.puzzle.givens[i] || locked(g) || (!g.board.values[i] && !g.board.notes[i])) return;
  remember(g); g.board.values[i] = 0; g.board.notes[i] = 0;
}
export function fillNotes(g: Game) {
  if (locked(g)) return;
  const notes = g.board.values.map((_, i) => candidates(g.board.values, i));
  if (notes.every((n, i) => n === g.board.notes[i])) return;
  remember(g); g.board.notes = notes;
}
export function undo(g: Game) { if (canUndo(g)) { g.redoStack.push(copy(g.board)); g.board = g.undoStack.pop()!; } }
export function redo(g: Game) { if (canRedo(g)) { g.undoStack.push(copy(g.board)); g.board = g.redoStack.pop()!; } }
export function validSave(value: unknown): value is Game {
  if (!value || typeof value !== 'object') return false;
  const g = value as Game, p = g.puzzle;
  if (!p || typeof p.id !== 'string' || !['easy', 'medium', 'hard', 'expert', 'custom'].includes(p.difficulty) ||
      !['collection', 'generated'].includes(p.source) || !['challenge', 'classic'].includes(g.mode) ||
      !complete(p.solution) || !consistent(p.givens) || !p.givens.every((v, i) => !v || v === p.solution[i]) ||
      !Number.isInteger(g.strikes) || g.strikes < 0 || !Number.isInteger(g.strikeLimit) || ![0, 3, 5, 10].includes(g.strikeLimit) ||
      !Number.isFinite(g.elapsed) || g.elapsed < 0 || typeof g.finished !== 'boolean' ||
      !Array.isArray(g.undoStack) || !Array.isArray(g.redoStack) || g.undoStack.length > 300 || g.redoStack.length > 300) return false;
  const valid = (b: Board) => b && Array.isArray(b.values) && Array.isArray(b.notes) && b.values.length === 81 && b.notes.length === 81 &&
    b.values.every((v, i) => Number.isInteger(v) && v >= 0 && v <= 9 && (!p.givens[i] || p.givens[i] === v)) &&
    b.notes.every(n => Number.isInteger(n) && n >= 0 && n <= all && (n & ~all) === 0);
  return !!(valid(g.board) && g.undoStack.every(valid) && g.redoStack.every(valid) && g.finished === complete(g.board.values));
}
