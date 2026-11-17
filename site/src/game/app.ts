import { canRedo, canUndo, createGame, enter, erase, fillNotes, isOut, leastFilledDigit, locked, redo, undo, validSave, type Game, type Result } from './game';
import { choosePuzzle } from './puzzles';
import { darkAppearance, defaults, restorePreferences, type Preferences } from './preferences';
import { digits, peers, type Difficulty, type Mode, type Puzzle, type Source } from './sudoku';
import { watchForUpdates } from './updates';

const $ = <T extends HTMLElement = HTMLElement>(selector: string) => document.querySelector<T>(selector)!;
const cells = [...document.querySelectorAll<HTMLButtonElement>('[data-cell]')];
const keys = [...document.querySelectorAll<HTMLButtonElement>('[data-digit]')];
const dialogs = [...document.querySelectorAll<HTMLDialogElement>('dialog')];
const newDialog = $('#new-dialog'), settingsDialog = $<HTMLDialogElement>('#settings-dialog');
const newForm = $<HTMLFormElement>('#new-form'), settingsForm = $<HTMLFormElement>('#settings-form');
const formField = (form: HTMLFormElement, name: string) => form.elements.namedItem(name) as HTMLInputElement | HTMLSelectElement;
const SAVE = 'gridzero.web.game.v1', PREFS = 'gridzero.web.preferences.v1';
const systemScheme = matchMedia('(prefers-color-scheme: dark)'), reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let preferences = { ...defaults }, game: Game | undefined, played: string[] = [], selected = -1, cursor = 0, focusedDigit = 0, pencil = false;
let checked = new Set<number>(), errorCell = -1, feedbackToken = 0, worker: Worker | undefined;
let lastTick: number | undefined, saveError = '', prefError = '', restoreError = '', generating = false;
type EntryTransition = { phase: 'idle' } | {
  phase: 'travelling' | 'recoiling'; index: number; result: Result;
  flight: HTMLElement; animation?: Animation; feedbackShown: boolean;
};
let transition: EntryTransition = { phase: 'idle' };

function save() {
  if (!game) return;
  try { localStorage.setItem(SAVE, JSON.stringify({ version: 1, game, played })); saveError = ''; }
  catch { saveError = "Couldn't save your progress. Keep this tab open; browser storage may be full or disabled."; }
  $('#save-status').textContent = saveError || prefError || restoreError;
}
function savePreferences() {
  try { localStorage.setItem(PREFS, JSON.stringify(preferences)); prefError = ''; }
  catch { prefError = "Couldn't save your settings. Browser storage may be disabled."; }
  $('#save-status').textContent = saveError || prefError || restoreError;
}
function appearance() {
  const dark = darkAppearance(preferences, systemScheme.matches);
  document.documentElement.dataset.scheme = dark ? 'dark' : 'light';
  document.documentElement.dataset.theme = preferences.theme;
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', dark ? '#151a1b' : '#faf9f5');
}
const title = (s: string) => s[0].toUpperCase() + s.slice(1);
const time = (elapsed: number) => `${Math.floor(elapsed / 60)}:${String(Math.floor(elapsed % 60)).padStart(2, '0')}`;
const canEdit = () => !!game && selected >= 0 && !game.puzzle.givens[selected] && !locked(game);
const canEnter = () => canEdit() && !game!.board.values[selected];
function startingFocus() {
  selected = -1;
  focusedDigit = leastFilledDigit(game!.board.values);
  cursor = Math.max(0, game!.board.values.indexOf(focusedDigit));
}
function selectCell(index: number) {
  selected = cursor = index;
  focusedDigit = game!.board.values[index];
}
function render() {
  appearance();
  if (!game) {
    keys.forEach(key => { key.disabled = true; });
    for (const id of ['undo', 'erase', 'notes']) $<HTMLButtonElement>(`#${id}`).disabled = true;
    $('#save-status').textContent = saveError || prefError || restoreError;
    return;
  }
  const g = game;
  const cellFocus = selected >= 0 && !focusedDigit;
  $('#board').dataset.focus = focusedDigit ? 'number' : 'cell';
  $('#board').dataset.digit = String(focusedDigit);
  cells.forEach((cell, i) => {
    const v = g.board.values[i], notes = digits(g.board.notes[i]);
    cell.querySelector('.value')!.textContent = v ? String(v) : '';
    cell.querySelectorAll<HTMLElement>('[data-note]').forEach(n => { const d = Number(n.dataset.note); n.textContent = notes.includes(d) ? String(d) : ''; });
    cell.classList.toggle('given', !!g.puzzle.givens[i]);
    cell.classList.toggle('has-value', !!v);
    const matching = preferences.highlightMatching && focusedDigit > 0 && v === focusedDigit;
    cell.classList.toggle('selected', cellFocus && i === selected);
    cell.classList.toggle('related', cellFocus && preferences.highlightPeers && peers[selected].includes(i));
    cell.classList.toggle('matching', matching);
    cell.classList.toggle('checked', checked.has(i));
    cell.classList.toggle('rejected', i === errorCell);
    cell.tabIndex = i === cursor ? 0 : -1;
    cell.setAttribute('aria-pressed', String(matching || (cellFocus && i === selected)));
    cell.setAttribute('aria-label', `Row ${Math.floor(i / 9) + 1}, column ${i % 9 + 1}, ${v ? `${v}${g.puzzle.givens[i] ? ', starting clue' : ''}` : `empty${notes.length ? `, notes ${notes.join(', ')}` : ''}`}${checked.has(i) ? ', needs another look' : ''}`);
  });
  $('#difficulty').textContent = g.puzzle.difficulty === 'custom' ? `Custom · ${g.puzzle.givens.filter(v => !v).length} empty` : title(g.puzzle.difficulty);
  $('#mode').textContent = title(g.mode);
  $('#timer').hidden = !preferences.showTimer;
  $('#timer').textContent = time(g.elapsed);
  $('#timer').setAttribute('aria-label', `Elapsed time ${time(g.elapsed)}`);
  const strikeDisplay = $('#strikes'); strikeDisplay.replaceChildren(); strikeDisplay.hidden = g.mode !== 'challenge';
  strikeDisplay.setAttribute('aria-label', g.strikeLimit ? `${g.strikes} of ${g.strikeLimit} strikes` : `${g.strikes} strikes`);
  if (g.strikeLimit > 0 && g.strikeLimit <= 5) {
    for (let i = 0; i < g.strikeLimit; i++) { const mark = document.createElement('span'); mark.textContent = '×'; mark.className = `strike${i < g.strikes ? ' used' : ''}`; mark.setAttribute('aria-hidden', 'true'); strikeDisplay.append(mark); }
  } else strikeDisplay.textContent = `× ${g.strikes}${g.strikeLimit ? ` / ${g.strikeLimit}` : ''}`;
  $<HTMLButtonElement>('#undo').disabled = !canUndo(g);
  $<HTMLButtonElement>('#erase').disabled = !canEdit();
  $<HTMLButtonElement>('#notes').disabled = locked(g);
  $('#notes').setAttribute('aria-pressed', String(pencil));
  $('.keypad').classList.toggle('pencil', pencil);
  for (const key of keys) {
    const d = Number(key.dataset.digit); key.disabled = !canEnter();
    key.classList.toggle('exhausted', g.board.values.filter(v => v === d).length >= 9);
    key.setAttribute('aria-label', `${pencil ? 'Toggle note' : 'Enter'} ${d}`);
  }
  $('[data-action="check"]').hidden = g.mode !== 'classic';
  $('[data-action="fill"]').hidden = !preferences.allowAutofill;
  $<HTMLButtonElement>('[data-action="fill"]').disabled = locked(g);
  $<HTMLButtonElement>('[data-action="redo"]').disabled = !canRedo(g);
  const status = $('#status'); status.classList.toggle('error', errorCell >= 0);
  status.textContent = errorCell >= 0 ? 'Incorrect number' : '';
  if (errorCell < 0 && isOut(g)) {
    const button = document.createElement('button');
    button.className = 'status-button'; button.textContent = 'Continue in Classic';
    button.onclick = () => { g.mode = 'classic'; render(); save(); };
    status.replaceChildren(button);
  }
  $('#save-status').textContent = saveError || prefError || restoreError;
}
function clearFlights() {
  finishEntry(false);
}
function openDialog(dialog: HTMLDialogElement) {
  clearFlights(); lastTick = undefined; save();
  for (const d of dialogs) if (d.open) d.close();
  dialog.showModal();
  const heading = dialog.querySelector<HTMLElement>('.dialog-header h2');
  if (heading?.textContent?.trim()) {
    heading.tabIndex = -1;
    heading.focus({ preventScroll: true });
  }
}
function notice(heading: string, message: string, actions: { label: string; run?: () => void }[] = [{ label: 'OK' }]) {
  $('#notice-title').textContent = heading; $('#notice-message').textContent = message;
  $('#notice-actions').replaceChildren();
  for (const action of actions) {
    const button = document.createElement('button'); button.textContent = action.label;
    button.onclick = () => { $<HTMLDialogElement>('#notice-dialog').close(); action.run?.(); };
    $('#notice-actions').append(button);
  }
  openDialog($<HTMLDialogElement>('#notice-dialog'));
}
function outcome() {
  if (!game) return;
  if (isOut(game)) notice('Strike limit reached', `${game.strikeLimit} strikes.`, [
    { label: 'Retry This Puzzle', run: restart },
    { label: 'Continue in Classic', run: () => { if (game) game.mode = 'classic'; checked.clear(); render(); save(); } },
    { label: 'New Puzzle', run: openNew },
  ]);
  else if (game.finished) notice('', '', [
    { label: 'New game', run: openNew }, { label: 'Admire puzzle' },
  ]);
}
function haptic(error = false) { if (preferences.haptics) navigator.vibrate?.(error ? [20, 40, 20] : 8); }
function entryFeedback(result: Result, index: number) {
  errorCell = result === 'strike' ? index : -1;
  if (result !== 'strike' && game) focusedDigit = game.board.values[index];
  haptic(result === 'strike'); render();
}
function finishEntry(presentOutcome = true) {
  if (transition.phase === 'idle') return;
  const active = transition;
  transition = { phase: 'idle' };
  active.animation?.cancel(); active.flight.remove();
  cells[active.index].classList.remove('flying');
  $('#board').setAttribute('aria-busy', 'false');
  $('#main').dataset.entryPhase = 'idle';
  if (!active.feedbackShown) entryFeedback(active.result, active.index);
  else render();
  if (active.result === 'strike') {
    const token = feedbackToken;
    setTimeout(() => { if (feedbackToken === token) { errorCell = -1; render(); } }, 700);
  }
  if (presentOutcome && game && (active.result === 'completed' || isOut(game))) outcome();
}
function animateEntry(digit: number, index: number, result: Result) {
  const key = keys.find(k => Number(k.dataset.digit) === digit)!;
  const source = key.getBoundingClientRect();
  const target = cells[index].getBoundingClientRect();
  const sourceFont = parseFloat(getComputedStyle(key).fontSize);
  const targetFont = parseFloat(getComputedStyle(cells[index]).fontSize);
  const flight = document.createElement('span'); flight.className = 'entry-flight'; flight.textContent = String(digit); flight.setAttribute('aria-hidden', 'true');
  flight.style.fontSize = `${sourceFont}px`;
  flight.style.fontWeight = getComputedStyle(cells[index]).fontWeight;
  flight.style.left = `${source.x + source.width / 2 + scrollX}px`; flight.style.top = `${source.y + source.height / 2 + scrollY}px`;
  const active: Exclude<EntryTransition, { phase: 'idle' }> = { phase: 'travelling', index, result, flight, feedbackShown: false };
  transition = active;
  $('#main').dataset.entryPhase = 'travelling';
  $('#board').setAttribute('aria-busy', 'true');
  document.body.append(flight);
  cells[index].classList.add('flying');
  const dx = target.x + target.width / 2 - source.x - source.width / 2, dy = target.y + target.height / 2 - source.y - source.height / 2;
  const base = 'translate(-50%,-50%)';
  const destination = `${base} translate(${dx}px,${dy}px) scale(${targetFont / sourceFont})`;
  active.animation = flight.animate([{ transform: base }, { transform: destination }], { duration: 350, easing: 'cubic-bezier(.2,.65,.3,1)', fill: 'forwards' });
  active.animation.onfinish = () => {
    if (transition !== active) return;
    if (result !== 'strike') { finishEntry(); return; }
    active.phase = 'recoiling'; active.feedbackShown = true;
    $('#main').dataset.entryPhase = 'recoiling';
    entryFeedback(result, index);
    cells[index].classList.remove('flying');
    active.animation!.cancel();
    active.animation = flight.animate([
      { transform: destination, color: 'var(--error)', opacity: 1 },
      { transform: `${base} scale(.75)`, color: 'var(--error)', opacity: 0 },
    ], { duration: 450, easing: 'ease-in', fill: 'forwards' });
    active.animation.onfinish = () => { if (transition === active) finishEntry(); };
  };
}
function canAnimate() { return typeof HTMLElement.prototype.animate === 'function'; }
function entry(digit: number) {
  if (!game || !canEnter() || transition.phase !== 'idle') return;
  errorCell = -1; feedbackToken++; render();
  checked.clear(); const result = enter(game, digit, selected, pencil, preferences.cleanupNotes);
  if (result === 'ignored') return;
  save();
  if (!pencil && !reducedMotion.matches && canAnimate()) {
    animateEntry(digit, selected, result);
  } else {
    entryFeedback(result, selected);
    if (result === 'strike') {
      const token = feedbackToken;
      setTimeout(() => { if (feedbackToken === token) { errorCell = -1; render(); } }, 700);
    }
    if (result === 'completed' || isOut(game)) outcome();
  }
}
function changed(action: () => void) { if (transition.phase !== 'idle') return; action(); if (selected >= 0) focusedDigit = game!.board.values[selected]; checked.clear(); errorCell = -1; feedbackToken++; render(); save(); }
function restart() {
  if (!game) return;
  changed(() => { game = createGame(game!.puzzle, game!.mode, game!.strikeLimit); startingFocus(); pencil = false; lastTick = undefined; });
}
function openNew() {
  clearFlights(); lastTick = undefined; save();
  dialogs.forEach(dialog => { if (dialog.open) dialog.close(); });
  for (const [name, value] of Object.entries({ difficulty: preferences.difficulty, mode: preferences.mode, source: preferences.source, empty: preferences.customEmpty })) formField(newForm, name).value = String(value);
  $('#generation-error').textContent = ''; updateNew();
  $('#main').hidden = true; newDialog.hidden = false;
  $('#lobby-error').textContent = saveError || prefError || restoreError;
  if (location.pathname !== '/') history.pushState(null, '', '/');
}
function showGame() {
  newDialog.hidden = true; $('#main').hidden = false;
  if (location.pathname !== '/play/') history.pushState(null, '', '/play/');
  cells[cursor].focus({ preventScroll: true });
}
function updateNew() {
  const custom = formField(newForm, 'difficulty').value === 'custom';
  $('#custom-field').hidden = !custom; formField(newForm, 'source').disabled = custom || generating;
  $('#empty-count').textContent = formField(newForm, 'empty').value;
}
$('#mode-info').addEventListener('click', () => {
  const mode = formField(newForm, 'mode').value;
  $('#mode-info-title').textContent = title(mode);
  $('#mode-info-message').textContent = mode === 'challenge' ?
    `Wrong entries are rejected and add a strike. ${preferences.strikeLimit ? `${preferences.strikeLimit} strikes end the attempt.` : 'No strike limit.'} Undo does not remove strikes. Notes are not checked.` :
    'Enter numbers without automatic checking or strikes. Use Check Board in the game menu to check your entries.';
  // Keep the chooser open underneath so its unsaved selections and focus survive.
  $<HTMLDialogElement>('#mode-info-dialog').showModal();
});
$<HTMLDialogElement>('#mode-info-dialog').addEventListener('close', () => {
  if (!newDialog.hidden) $('#mode-info').focus();
});
function setGenerating(value: boolean) {
  generating = value;
  for (const field of newForm.querySelectorAll<HTMLInputElement | HTMLSelectElement | HTMLButtonElement>('input, select, button')) field.disabled = value;
  $('#start-puzzle').textContent = value ? 'Preparing…' : 'Play';
  $('#cancel-generation').hidden = !value;
  $<HTMLButtonElement>('#cancel-generation').disabled = false; updateNew();
}
function cancelGeneration() {
  worker?.terminate(); worker = undefined; setGenerating(false);
}
$('#cancel-generation').addEventListener('click', cancelGeneration);
function installPuzzle(puzzle: Puzzle, mode: Mode, source: Source, empty: number) {
  game = createGame(puzzle, mode, preferences.strikeLimit); startingFocus();
  checked.clear(); errorCell = -1; feedbackToken++; pencil = false; clearFlights(); lastTick = undefined;
  played = [...played, puzzle.id].slice(-500); restoreError = '';
  Object.assign(preferences, { difficulty: puzzle.difficulty, mode, source, customEmpty: empty });
  savePreferences(); save(); render();
}
newForm.addEventListener('submit', event => {
  event.preventDefault(); if (generating) return;
  const difficulty = formField(newForm, 'difficulty').value as Difficulty, mode = formField(newForm, 'mode').value as Mode;
  const source = difficulty === 'custom' ? 'generated' : formField(newForm, 'source').value as Source;
  const empty = Number(formField(newForm, 'empty').value); $('#generation-error').textContent = '';
  if (source === 'collection') {
    try { installPuzzle(choosePuzzle(difficulty, played), mode, source, empty); showGame(); }
    catch (error) { $('#generation-error').textContent = (error as Error).message; }
    return;
  }
  try {
    const pending = new Worker(new URL('./generator.worker.ts', import.meta.url), { type: 'module' }); worker = pending; setGenerating(true);
    pending.onmessage = (event: MessageEvent<{ puzzle?: Puzzle; error?: string }>) => {
      if (worker !== pending) return;
      cancelGeneration();
      if (event.data.puzzle) { installPuzzle(event.data.puzzle, mode, source, empty); showGame(); }
      else $('#generation-error').textContent = event.data.error || 'Could not generate a puzzle.';
    };
    pending.onerror = () => { if (worker !== pending) return; cancelGeneration(); $('#generation-error').textContent = 'Generation could not start. Try again or use the collection.'; };
    pending.postMessage({ difficulty, empty });
  } catch { cancelGeneration(); $('#generation-error').textContent = 'Generation is unavailable in this browser. Use the collection instead.'; }
});
newForm.addEventListener('input', updateNew); newForm.addEventListener('change', updateNew);
function openSettings() {
  for (const field of settingsForm.querySelectorAll<HTMLInputElement | HTMLSelectElement>('[name]')) {
    const key = field.name as keyof Preferences, value = preferences[key];
    if (field instanceof HTMLInputElement && field.type === 'checkbox') field.checked = !!value;
    else if (field instanceof HTMLInputElement && field.type === 'time') field.value = `${String(Math.floor(Number(value) / 60)).padStart(2, '0')}:${String(Number(value) % 60).padStart(2, '0')}`;
    else field.value = String(value);
  }
  updateSettings(); openDialog(settingsDialog);
}
function updateSettings() {
  $('#schedule').hidden = preferences.appearance !== 'scheduled';
  formField(settingsForm, 'strikeLimit').value = String(preferences.strikeLimit);
  $<HTMLButtonElement>('#strike-decrease').disabled = preferences.strikeLimit <= 1;
  $<HTMLButtonElement>('#strike-increase').disabled = preferences.strikeLimit >= 5;
  document.querySelectorAll<HTMLElement>('[data-theme-choice]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.themeChoice === preferences.theme)));
}
settingsForm.addEventListener('submit', e => e.preventDefault());
settingsForm.addEventListener('change', event => {
  const field = event.target as HTMLInputElement | HTMLSelectElement;
  if (!field.name) return;
  let value: unknown = field.value;
  if (field instanceof HTMLInputElement && field.type === 'checkbox') value = field.checked;
  if (field.name === 'strikeLimit') value = field.value.trim() && Number.isFinite(Number(field.value)) ?
    Math.max(1, Math.min(5, Math.round(Number(field.value)))) : preferences.strikeLimit;
  if (field instanceof HTMLInputElement && field.type === 'time') { if (!field.value) return; const [h, m] = field.value.split(':').map(Number); value = h * 60 + m; }
  preferences = restorePreferences({ ...preferences, [field.name]: value });
  updateSettings(); savePreferences(); render();
});
document.querySelectorAll<HTMLElement>('[data-theme-choice]').forEach(b => b.addEventListener('click', () => {
  preferences.theme = b.dataset.themeChoice as Preferences['theme']; updateSettings(); savePreferences(); render();
}));
for (const [id, delta] of [['strike-decrease', -1], ['strike-increase', 1]] as const) {
  $(`#${id}`).addEventListener('click', () => {
    preferences.strikeLimit = Math.max(1, Math.min(5, preferences.strikeLimit + delta));
    updateSettings(); savePreferences();
  });
}
cells.forEach((cell, i) => cell.addEventListener('click', () => { if (transition.phase !== 'idle') return; selectCell(i); render(); }));
keys.forEach(key => key.addEventListener('click', () => entry(Number(key.dataset.digit))));
$('#undo').addEventListener('click', () => changed(() => { if (game) undo(game); }));
$('#erase').addEventListener('click', () => changed(() => { if (game) erase(game, selected); }));
$('#notes').addEventListener('click', () => { if (transition.phase !== 'idle') return; pencil = !pencil; haptic(); render(); });
$('#menu-open').addEventListener('click', () => { clearFlights(); render(); openDialog($<HTMLDialogElement>('#menu-dialog')); });
document.querySelectorAll<HTMLElement>('[data-action]').forEach(button => button.addEventListener('click', () => {
  $<HTMLDialogElement>('#menu-dialog').close();
  if (button.dataset.action === 'new') { openNew(); return; }
  if (button.dataset.action === 'settings') { openSettings(); return; }
  if (!game) return;
  switch (button.dataset.action) {
    case 'redo': changed(() => redo(game!)); break;
    case 'fill': changed(() => fillNotes(game!)); break;
    case 'restart': notice('Restart this puzzle?', 'Your entries, notes, strikes, and time will be reset.', [{ label: 'Restart', run: restart }, { label: 'Cancel' }]); break;
    case 'check': {
      checked = new Set(game.board.values.map((v, i) => v && v !== game!.puzzle.solution[i] ? i : -1).filter(i => i >= 0)); render();
      notice(checked.size ? 'A second look' : 'Looking good', checked.size ? `${checked.size} ${checked.size === 1 ? 'cell needs' : 'cells need'} another look. They're marked on the board.` : 'All your entered numbers are correct so far.'); break;
    }
  }
}));
dialogs.forEach(dialog => {
  dialog.querySelectorAll('[data-close]').forEach(b => b.addEventListener('click', () => dialog.close()));
  dialog.addEventListener('close', () => { lastTick = undefined; save(); });
});
document.addEventListener('keydown', event => {
  if (!newDialog.hidden || dialogs.some(d => d.open) || !game || event.altKey || event.target instanceof HTMLInputElement || event.target instanceof HTMLSelectElement) return;
  if (transition.phase !== 'idle') {
    if (/^[1-9n]$/i.test(event.key) || ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Backspace', 'Delete', 'z'].includes(event.key)) event.preventDefault();
    return;
  }
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z') {
    event.preventDefault(); changed(() => event.shiftKey ? redo(game!) : undo(game!)); return;
  }
  if (event.ctrlKey || event.metaKey) return;
  const movement: Record<string, number> = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -9, ArrowDown: 9 };
  if (event.key in movement) { event.preventDefault(); selectCell((cursor + movement[event.key] + 81) % 81); render(); cells[cursor].focus(); }
  else if (/^[1-9]$/.test(event.key)) { event.preventDefault(); entry(Number(event.key)); }
  else if (event.key === 'Backspace' || event.key === 'Delete') { event.preventDefault(); changed(() => erase(game!, selected)); }
  else if (event.key.toLowerCase() === 'n' && !locked(game)) { event.preventDefault(); pencil = !pencil; render(); }
});
systemScheme.addEventListener('change', appearance); reducedMotion.addEventListener('change', () => finishEntry());
window.addEventListener('resize', () => finishEntry());
document.addEventListener('visibilitychange', () => { lastTick = undefined; finishEntry(); save(); });
window.addEventListener('pagehide', save);
setInterval(() => {
  const now = Date.now(); appearance();
  if (game && newDialog.hidden && !locked(game) && !document.hidden && !dialogs.some(d => d.open)) {
    if (lastTick !== undefined) game.elapsed += Math.max(0, Math.min(5, (now - lastTick) / 1000));
    lastTick = now; $('#timer').textContent = time(game.elapsed);
    $('#timer').setAttribute('aria-label', `Elapsed time ${time(game.elapsed)}`);
  } else lastTick = undefined;
}, 1000);
setInterval(save, 10_000);

try { preferences = restorePreferences(JSON.parse(localStorage.getItem(PREFS) || 'null')); }
catch { prefError = 'Your settings could not be restored. Using defaults.'; }
try {
  const raw = localStorage.getItem(SAVE);
  if (raw) {
    const envelope = JSON.parse(raw);
    if (envelope.version !== 1 || !validSave(envelope.game) || !Array.isArray(envelope.played) || !envelope.played.every((id: unknown) => typeof id === 'string')) throw new Error('Invalid save');
    game = envelope.game; played = envelope.played.slice(-500); startingFocus();
  }
} catch { restoreError = "Your previous save couldn't be restored."; }
render();
if (location.pathname === '/' || !game) openNew();
else if (isOut(game)) outcome();
window.addEventListener('popstate', () => {
  cancelGeneration();
  if (location.pathname === '/' || !game) openNew();
  else { dialogs.forEach(d => { if (d.open) d.close(); }); showGame(); }
});

if (import.meta.env.PROD) {
  void watchForUpdates(() => { save(); return !saveError; });
}
