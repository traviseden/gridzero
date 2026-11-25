import { canRedo, canUndo, locked, validSave } from './game';
import { Gameplay, type Edit, type Move, type Overlay } from './machine';
import { armSound, playSound } from './sound';
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
// Lobby and game share one document; their scroll positions are not interchangeable.
history.scrollRestoration = 'manual';
const resetScroll = () => window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
window.addEventListener('pageshow', resetScroll);
const flow = new Gameplay();
let preferences = { ...defaults }, played: string[] = [];
let checked = new Set<number>(), errorCell = -1, feedbackToken = 0, worker: Worker | undefined;
let lastTick: number | undefined, saveError = '', prefError = '', restoreError = '';
let visual: { flight: HTMLElement; animation: Animation } | undefined;

function save() {
  const game = flow.game;
  if (!game) return;
  try { localStorage.setItem(SAVE, JSON.stringify({ version: 1, game, played })); saveError = ''; }
  catch { saveError = "Couldn't save your progress. Keep this tab open; browser storage may be full or disabled."; }
  $('#save-status').textContent = saveError || prefError || restoreError;
  $('#lobby-error').textContent = saveError || prefError || restoreError;
}
function savePreferences() {
  try { localStorage.setItem(PREFS, JSON.stringify(preferences)); prefError = ''; }
  catch { prefError = "Couldn't save your settings. Browser storage may be disabled."; }
  $('#save-status').textContent = saveError || prefError || restoreError;
  $('#lobby-error').textContent = saveError || prefError || restoreError;
}
function appearance() {
  const root = document.documentElement;
  const scheme = darkAppearance(preferences, systemScheme.matches) ? 'dark' : 'light';
  if (root.dataset.scheme === scheme && root.dataset.theme === preferences.theme) return;
  root.dataset.scheme = scheme;
  root.dataset.theme = preferences.theme;
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', getComputedStyle(root).backgroundColor);
}
const title = (s: string) => s[0].toUpperCase() + s.slice(1);
const time = (elapsed: number) => `${Math.floor(elapsed / 60)}:${String(Math.floor(elapsed % 60)).padStart(2, '0')}`;
function render() {
  const { game, selected, focusedDigit, cursor, pencil } = flow;
  appearance();
  if (!game) {
    keys.forEach(key => { key.disabled = true; });
    for (const id of ['undo', 'erase', 'notes']) $<HTMLButtonElement>(`#${id}`).disabled = true;
    $('#save-status').textContent = saveError || prefError || restoreError;
    return;
  }
  const g = game;
  const canEdit = selected >= 0 && !g.puzzle.givens[selected] && !locked(g);
  const canEnter = canEdit && !g.board.values[selected];
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
  $<HTMLButtonElement>('#erase').disabled = !canEdit;
  $<HTMLButtonElement>('#notes').disabled = locked(g);
  $('#notes').setAttribute('aria-pressed', String(pencil));
  $('.keypad').classList.toggle('pencil', pencil);
  for (const key of keys) {
    const d = Number(key.dataset.digit); key.disabled = !canEnter;
    key.classList.toggle('exhausted', g.board.values.filter(v => v === d).length >= 9);
    key.setAttribute('aria-label', `${pencil ? 'Toggle note' : 'Enter'} ${d}`);
  }
  $('[data-action="check"]').hidden = g.mode !== 'classic';
  $('[data-action="fill"]').hidden = !preferences.allowAutofill;
  $<HTMLButtonElement>('[data-action="fill"]').disabled = locked(g);
  $<HTMLButtonElement>('[data-action="redo"]').disabled = !canRedo(g);
  const status = $('#status'); status.classList.toggle('error', errorCell >= 0);
  status.textContent = errorCell >= 0 ? 'Incorrect number' : '';
  if (errorCell < 0 && flow.session === 'struck-out') {
    const button = document.createElement('button');
    button.className = 'status-button'; button.textContent = 'Continue in Classic';
    button.onclick = continueClassic;
    status.replaceChildren(button);
  }
  $('#save-status').textContent = saveError || prefError || restoreError;
}
const overlayName = (dialog: HTMLDialogElement) => dialog.id.replace(/-dialog$/, '') as Overlay;
function closeDialog(dialog: HTMLDialogElement) {
  flow.close(overlayName(dialog));
  dialog.close();
}
function openDialog(dialog: HTMLDialogElement) {
  finishEntry(false);
  if (!flow.open(overlayName(dialog))) return;
  lastTick = undefined; save();
  for (const d of dialogs) if (d.open && d !== dialog) d.close();
  if (dialog.open) return;
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
    button.onclick = () => { closeDialog($<HTMLDialogElement>('#notice-dialog')); action.run?.(); };
    $('#notice-actions').append(button);
  }
  openDialog($<HTMLDialogElement>('#notice-dialog'));
}
function outcome() {
  const game = flow.game;
  if (!game || !flow.boardOpen) return;
  if (flow.session === 'struck-out') {
    notice('Strike limit reached', `${game.strikeLimit} strikes.`, [
      { label: 'New Puzzle', run: openNew },
      { label: 'Retry This Puzzle', run: restart },
      { label: 'Continue in Classic', run: continueClassic },
    ]);
    $('#notice-actions button').focus({ preventScroll: true });
  }
  else if (flow.session === 'completed') notice('', '', [
    { label: 'New game', run: openNew }, { label: 'Admire puzzle' },
  ]);
}
function haptic(error = false) { if (preferences.haptics) navigator.vibrate?.(error ? [20, 40, 20] : 8); }
function entryFeedback(move: Move) {
  errorCell = move.rejected ? move.index : -1;
  if (move.cue && preferences.sound && !document.hidden) playSound(move.cue);
  haptic(move.rejected);
}
function finishEntry(presentOutcome = true) {
  if (flow.entry.phase === 'idle') return;
  const { move } = flow.entry;
  const feedback = flow.settle(move);
  visual?.animation.cancel(); visual?.flight.remove(); visual = undefined;
  cells[move.index].classList.remove('flying');
  $('#board').setAttribute('aria-busy', 'false');
  $('#main').dataset.entryPhase = 'idle';
  if (feedback) entryFeedback(feedback);
  render();
  if (move.rejected) {
    const token = feedbackToken;
    setTimeout(() => { if (feedbackToken === token) { errorCell = -1; render(); } }, 700);
  }
  if (presentOutcome) outcome();
}
function animateEntry(move: Move) {
  const { digit, index } = move;
  const key = keys.find(k => Number(k.dataset.digit) === digit)!;
  const source = key.getBoundingClientRect();
  const target = cells[index].getBoundingClientRect();
  const sourceFont = parseFloat(getComputedStyle(key).fontSize);
  const targetFont = parseFloat(getComputedStyle(cells[index]).fontSize);
  const flight = document.createElement('span'); flight.className = 'entry-flight'; flight.textContent = String(digit); flight.setAttribute('aria-hidden', 'true');
  flight.style.fontSize = `${sourceFont}px`;
  flight.style.fontWeight = getComputedStyle(cells[index]).fontWeight;
  flight.style.left = `${source.x + source.width / 2 + scrollX}px`; flight.style.top = `${source.y + source.height / 2 + scrollY}px`;
  $('#main').dataset.entryPhase = 'travelling';
  $('#board').setAttribute('aria-busy', 'true');
  document.body.append(flight);
  cells[index].classList.add('flying');
  const dx = target.x + target.width / 2 - source.x - source.width / 2, dy = target.y + target.height / 2 - source.y - source.height / 2;
  const base = 'translate(-50%,-50%)';
  const destination = `${base} translate(${dx}px,${dy}px) scale(${targetFont / sourceFont})`;
  const animation = flight.animate([{ transform: base }, { transform: destination }], { duration: 350, easing: 'cubic-bezier(.2,.65,.3,1)', fill: 'forwards' });
  visual = { flight, animation };
  animation.onfinish = () => {
    if (flow.entry.phase !== 'travelling' || flow.entry.move !== move) return;
    if (!move.rejected) { finishEntry(); return; }
    const feedback = flow.arrive(move);
    $('#main').dataset.entryPhase = 'recoiling';
    if (feedback) entryFeedback(feedback);
    render();
    cells[index].classList.remove('flying');
    animation.cancel();
    const recoil = flight.animate([
      { transform: destination, color: 'var(--error)', opacity: 1 },
      { transform: `${base} scale(.75)`, color: 'var(--error)', opacity: 0 },
    ], { duration: 450, easing: 'ease-in', fill: 'forwards' });
    visual = { flight, animation: recoil };
    recoil.onfinish = () => { if (flow.entry.phase === 'recoiling' && flow.entry.move === move) finishEntry(); };
  };
}
function canAnimate() { return typeof HTMLElement.prototype.animate === 'function'; }
function entry(digit: number) {
  const move = flow.guess(digit, preferences.cleanupNotes);
  if (!move) return;
  if (move.cue && preferences.sound) armSound();
  checked.clear(); errorCell = -1; feedbackToken++;
  save();
  if (!flow.pencil && !reducedMotion.matches && canAnimate()) animateEntry(move);
  else finishEntry();
}
function refreshEdit() { checked.clear(); errorCell = -1; feedbackToken++; render(); save(); }
function edit(action: Edit) { if (flow.edit(action)) refreshEdit(); }
function continueClassic() { if (flow.continueClassic()) refreshEdit(); }
function restart() {
  if (flow.restart()) { lastTick = undefined; refreshEdit(); }
}
function openNew() {
  finishEntry(false); flow.navigate(false); lastTick = undefined; save();
  dialogs.forEach(dialog => { if (dialog.open) dialog.close(); });
  for (const [name, value] of Object.entries({ difficulty: preferences.difficulty, mode: preferences.mode, source: preferences.source, empty: preferences.customEmpty })) formField(newForm, name).value = String(value);
  $('#generation-error').textContent = ''; updateNew();
  $('#main').hidden = true; newDialog.hidden = false;
  $('#lobby-error').textContent = saveError || prefError || restoreError;
  if (location.pathname !== '/') history.pushState(null, '', '/');
  resetScroll();
}
function showGame() {
  flow.navigate(true);
  newDialog.hidden = true; $('#main').hidden = false;
  if (location.pathname !== '/play/') history.pushState(null, '', '/play/');
  cells[flow.cursor].focus({ preventScroll: true });
  resetScroll();
}
function updateNew() {
  const custom = formField(newForm, 'difficulty').value === 'custom';
  $('#custom-field').hidden = !custom; formField(newForm, 'source').disabled = custom || flow.screen === 'preparing';
  $('#empty-count').textContent = formField(newForm, 'empty').value;
}
$('#mode-info').addEventListener('click', () => {
  const mode = formField(newForm, 'mode').value;
  $('#mode-info-title').textContent = title(mode);
  $('#mode-info-message').textContent = mode === 'challenge' ?
    `Wrong entries are rejected and add a strike. ${preferences.strikeLimit ? `${preferences.strikeLimit} strikes end the attempt.` : 'No strike limit.'} Undo does not remove strikes. Notes are not checked.` :
    'Enter numbers without automatic checking or strikes. Use Check Board in the game menu to check your entries.';
  // Keep the chooser open underneath so its unsaved selections and focus survive.
  openDialog($<HTMLDialogElement>('#mode-info-dialog'));
});
$<HTMLDialogElement>('#mode-info-dialog').addEventListener('close', () => {
  if (flow.screen === 'setup' && !flow.overlay) $('#mode-info').focus();
});
function renderPreparation() {
  const value = flow.screen === 'preparing';
  $<HTMLButtonElement>('#lobby-settings').disabled = value;
  for (const field of newForm.querySelectorAll<HTMLInputElement | HTMLSelectElement | HTMLButtonElement>('input, select, button')) field.disabled = value;
  $('#start-puzzle').textContent = value ? 'Preparing…' : 'Play';
  $('#cancel-generation').hidden = !value;
  $<HTMLButtonElement>('#cancel-generation').disabled = false; updateNew();
}
function cancelGeneration() {
  worker?.terminate(); worker = undefined; flow.cancel(); renderPreparation();
}
$('#cancel-generation').addEventListener('click', cancelGeneration);
function installPuzzle(request: number, puzzle: Puzzle, mode: Mode, source: Source, empty: number) {
  if (!flow.install(request, puzzle, mode, preferences.strikeLimit)) return;
  worker?.terminate(); worker = undefined; renderPreparation();
  checked.clear(); errorCell = -1; feedbackToken++; lastTick = undefined;
  played = [...played, puzzle.id].slice(-500); restoreError = '';
  Object.assign(preferences, { difficulty: puzzle.difficulty, mode, source, customEmpty: empty });
  savePreferences(); save(); render(); showGame();
}
newForm.addEventListener('submit', event => {
  event.preventDefault();
  const request = flow.prepare();
  if (request === undefined) return;
  const difficulty = formField(newForm, 'difficulty').value as Difficulty, mode = formField(newForm, 'mode').value as Mode;
  const source = difficulty === 'custom' ? 'generated' : formField(newForm, 'source').value as Source;
  const empty = Number(formField(newForm, 'empty').value); $('#generation-error').textContent = '';
  if (source === 'collection') {
    try { installPuzzle(request, choosePuzzle(difficulty, played), mode, source, empty); }
    catch (error) { cancelGeneration(); $('#generation-error').textContent = (error as Error).message; }
    return;
  }
  try {
    const pending = new Worker(new URL('./generator.worker.ts', import.meta.url), { type: 'module' }); worker = pending; renderPreparation();
    pending.onmessage = (event: MessageEvent<{ puzzle?: Puzzle; error?: string }>) => {
      if (worker !== pending) return;
      if (event.data.puzzle) installPuzzle(request, event.data.puzzle, mode, source, empty);
      else { cancelGeneration(); $('#generation-error').textContent = event.data.error || 'Could not generate a puzzle.'; }
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
  if (field.name === 'source' && flow.screen === 'setup') {
    formField(newForm, 'source').value = preferences.source;
    updateNew();
  }
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
cells.forEach((cell, i) => cell.addEventListener('click', () => {
  if (flow.entry.phase !== 'idle' || !flow.boardOpen) return;
  flow.select(i); render();
  if (flow.session === 'challenge' && preferences.sound) armSound();
}));
keys.forEach(key => key.addEventListener('click', () => entry(Number(key.dataset.digit))));
$('#undo').addEventListener('click', () => edit('undo'));
$('#erase').addEventListener('click', () => edit('erase'));
$('#notes').addEventListener('click', () => { if (flow.edit('notes')) { haptic(); render(); } });
$('#menu-open').addEventListener('click', () => openDialog($<HTMLDialogElement>('#menu-dialog')));
$('#lobby-settings').addEventListener('click', openSettings);
settingsDialog.addEventListener('close', () => {
  if (flow.screen === 'setup' && !settingsDialog.open) $('#lobby-settings').focus({ preventScroll: true });
});
document.querySelectorAll<HTMLElement>('[data-action]').forEach(button => button.addEventListener('click', () => {
  closeDialog($<HTMLDialogElement>('#menu-dialog'));
  if (button.dataset.action === 'new') { openNew(); return; }
  if (button.dataset.action === 'settings') { openSettings(); return; }
  const game = flow.game;
  if (!game) return;
  switch (button.dataset.action) {
    case 'redo': edit('redo'); break;
    case 'fill': if (preferences.allowAutofill) edit('fill'); break;
    case 'restart': notice('Restart this puzzle?', 'Your entries, notes, strikes, and time will be reset.', [{ label: 'Restart', run: restart }, { label: 'Cancel' }]); break;
    case 'check': {
      if (game.mode !== 'classic') break;
      checked = new Set(game.board.values.map((v, i) => v && v !== game.puzzle.solution[i] ? i : -1).filter(i => i >= 0)); render();
      notice(checked.size ? 'A second look' : 'Looking good', checked.size ? `${checked.size} ${checked.size === 1 ? 'cell needs' : 'cells need'} another look. They're marked on the board.` : 'All your entered numbers are correct so far.'); break;
    }
  }
}));
dialogs.forEach(dialog => {
  dialog.querySelectorAll('[data-close]').forEach(b => b.addEventListener('click', () => closeDialog(dialog)));
  dialog.addEventListener('cancel', () => flow.close(overlayName(dialog)));
  dialog.addEventListener('close', () => { if (!dialog.open) flow.close(overlayName(dialog)); lastTick = undefined; save(); });
});
document.addEventListener('keydown', event => {
  if (!flow.boardOpen || event.altKey || event.target instanceof HTMLInputElement || event.target instanceof HTMLSelectElement) return;
  if (flow.entry.phase !== 'idle') {
    if (/^[1-9n]$/i.test(event.key) || ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Backspace', 'Delete', 'z'].includes(event.key)) event.preventDefault();
    return;
  }
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z') {
    event.preventDefault(); edit(event.shiftKey ? 'redo' : 'undo'); return;
  }
  if (event.ctrlKey || event.metaKey) return;
  const movement: Record<string, number> = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -9, ArrowDown: 9 };
  if (event.key in movement) { event.preventDefault(); flow.select((flow.cursor + movement[event.key] + 81) % 81); render(); cells[flow.cursor].focus(); }
  else if (/^[1-9]$/.test(event.key)) { event.preventDefault(); entry(Number(event.key)); }
  else if (event.key === 'Backspace' || event.key === 'Delete') { event.preventDefault(); edit('erase'); }
  else if (event.key.toLowerCase() === 'n' && flow.ready) { event.preventDefault(); flow.edit('notes'); render(); }
});
systemScheme.addEventListener('change', appearance); reducedMotion.addEventListener('change', () => finishEntry());
window.addEventListener('resize', () => finishEntry());
document.addEventListener('visibilitychange', () => { lastTick = undefined; finishEntry(); save(); });
window.addEventListener('pagehide', save);
setInterval(() => {
  const now = Date.now(); appearance();
  const game = flow.game;
  if (game && flow.playing && !document.hidden) {
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
    flow.restore(envelope.game); played = envelope.played.slice(-500);
  }
} catch { restoreError = "Your previous save couldn't be restored."; }
render();
if (location.pathname === '/' || !flow.game) openNew();
else { showGame(); if (flow.session === 'struck-out') outcome(); }
window.addEventListener('popstate', () => {
  cancelGeneration();
  if (location.pathname === '/' || !flow.game) openNew();
  else { dialogs.forEach(d => { if (d.open) d.close(); }); showGame(); }
});

if (import.meta.env.PROD) {
  void watchForUpdates(() => { save(); return !saveError; });
}
