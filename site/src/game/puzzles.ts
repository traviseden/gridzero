// Import the native collection directly: one source of truth, no runtime fetch.
import collection from '../../../Sources/GridZeroCore/Resources/puzzles.txt?raw';
import { solutions, type Difficulty, type Puzzle } from './sudoku';
export const records = collection.trim().split('\n').filter(line => !line.startsWith('#')).map(line => {
  const [difficulty, id, board, rating] = line.trim().split(/\s+/);
  return { difficulty: difficulty as Difficulty, id, givens: [...board].map(Number), rating: Number(rating) };
});
export function choosePuzzle(difficulty: Difficulty, played: string[] = []): Puzzle {
  const options = records.filter(p => p.difficulty === difficulty);
  const unseen = options.filter(p => !played.includes(p.id));
  const pool = unseen.length ? unseen : options;
  const record = pool[Math.floor(Math.random() * pool.length)];
  if (!record) throw new Error('The puzzle collection could not be loaded.');
  const solution = solutions(record.givens, 1)[0];
  if (!solution) throw new Error('The puzzle collection could not be loaded.');
  return { ...record, givens: [...record.givens], solution, source: 'collection' };
}
