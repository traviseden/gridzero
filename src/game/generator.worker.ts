import { generate, type Difficulty } from './sudoku';
self.onmessage = (event: MessageEvent<{ difficulty: Difficulty; empty: number }>) => {
  try { self.postMessage({ puzzle: generate(event.data.difficulty, event.data.empty) }); }
  catch (error) { self.postMessage({ error: error instanceof Error ? error.message : 'Could not generate a puzzle.' }); }
};
