import { createGame, enter, erase, fillNotes, isOut, leastFilledDigit, redo, undo, type Game } from './game';
import type { Mode, Puzzle } from './sudoku';

type Screen = 'setup' | 'preparing' | 'board';
export type Overlay = 'menu' | 'settings' | 'mode-info' | 'notice';
export type Cue = 'correct' | 'incorrect' | 'win';
export type Move = { index: number; digit: number; rejected: boolean; cue?: Cue };
type Entry = { phase: 'idle' } | { phase: 'travelling' | 'recoiling'; move: Move };
export type Edit = 'undo' | 'redo' | 'erase' | 'fill' | 'notes';

// Only Game is durable. Routes, dialogs, flights and worker requests start
// fresh on restore. No DOM, timers, audio or storage in these transitions.
export class Gameplay {
  screen: Screen = 'setup';
  overlay: Overlay | null = null;
  game?: Game;
  entry: Entry = { phase: 'idle' };
  selected = -1;
  cursor = 0;
  focusedDigit = 0;
  pencil = false;
  private request = 0;

  get session() {
    if (!this.game) return 'empty';
    return this.game.finished ? 'completed' : isOut(this.game) ? 'struck-out' : this.game.mode;
  }
  get boardOpen() { return this.screen === 'board' && !this.overlay; }
  get playing() { return this.boardOpen && (this.session === 'challenge' || this.session === 'classic'); }
  get ready() { return this.playing && this.entry.phase === 'idle'; }

  restore(game: Game) {
    this.game = game;
    this.selected = -1;
    this.pencil = false;
    this.entry = { phase: 'idle' };
    this.focusedDigit = leastFilledDigit(game.board.values);
    this.cursor = Math.max(0, game.board.values.indexOf(this.focusedDigit));
  }
  navigate(board: boolean) {
    this.screen = board && this.game ? 'board' : 'setup';
    this.overlay = null;
  }
  prepare() {
    if (this.screen !== 'setup' || this.overlay) return;
    this.screen = 'preparing';
    return ++this.request;
  }
  cancel() { if (this.screen === 'preparing') this.screen = 'setup'; }
  install(request: number, puzzle: Puzzle, mode: Mode, limit: number) {
    if (this.screen !== 'preparing' || this.request !== request) return false;
    this.restore(createGame(puzzle, mode, limit));
    this.navigate(true);
    return true;
  }
  open(overlay: Overlay) {
    if (this.screen === 'preparing' || (overlay === 'mode-info' && this.screen !== 'setup') ||
        ((overlay === 'notice' || overlay === 'menu') && this.screen !== 'board')) return false;
    this.overlay = overlay;
    return true;
  }
  close(overlay: Overlay) { if (this.overlay === overlay) this.overlay = null; }
  select(index: number) {
    // Allow keyboard exploration of a completed board.
    if (!this.boardOpen || this.entry.phase !== 'idle' || !this.game) return;
    this.selected = this.cursor = index;
    this.focusedDigit = this.game.board.values[index];
  }
  guess(digit: number, cleanup: boolean) {
    if (!this.ready || !this.game) return;
    const result = enter(this.game, digit, this.selected, this.pencil, cleanup);
    if (result === 'ignored') return;
    const rejected = result === 'strike';
    const cue = result === 'completed' ? 'win'
      : !this.pencil && this.game.mode === 'challenge' ? (rejected ? 'incorrect' : 'correct') : undefined;
    const move: Move = { digit, index: this.selected, rejected, cue };
    this.entry = { phase: 'travelling', move };
    return move;
  }
  // Feedback is delivered at most once, even if resize and animation-end race.
  arrive(move: Move) {
    if (this.entry.phase !== 'travelling' || this.entry.move !== move) return;
    this.entry = move.rejected ? { phase: 'recoiling', move } : { phase: 'idle' };
    if (!move.rejected) this.focusedDigit = this.game!.board.values[move.index];
    return move;
  }
  settle(move: Move) {
    if (this.entry.phase === 'idle' || this.entry.move !== move) return;
    const feedback = this.arrive(move);
    this.entry = { phase: 'idle' };
    return feedback;
  }
  edit(action: Edit) {
    if (!this.ready || !this.game) return false;
    if (action === 'notes') this.pencil = !this.pencil;
    else {
      if (action === 'erase') erase(this.game, this.selected);
      else ({ undo, redo, fill: fillNotes }[action])(this.game);
      if (this.selected >= 0) this.focusedDigit = this.game.board.values[this.selected];
    }
    return true;
  }
  restart() {
    if (!this.boardOpen || !this.game || this.entry.phase !== 'idle') return false;
    this.restore(createGame(this.game.puzzle, this.game.mode, this.game.strikeLimit));
    return true;
  }
  continueClassic() {
    if (!this.boardOpen || this.entry.phase !== 'idle' || this.session !== 'struck-out' || !this.game) return false;
    this.game.mode = 'classic';
    return true;
  }
}
