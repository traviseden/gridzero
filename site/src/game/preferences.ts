import type { Difficulty, Mode, Source } from './sudoku';
export interface Preferences {
  theme: 'ink' | 'moss' | 'clay'; appearance: 'system' | 'light' | 'dark' | 'scheduled';
  lightAt: number; darkAt: number; source: Source; difficulty: Difficulty; mode: Mode;
  strikeLimit: number; customEmpty: number; allowAutofill: boolean; cleanupNotes: boolean;
  highlightPeers: boolean; highlightMatching: boolean; showTimer: boolean; haptics: boolean; sound: boolean;
}
export const defaults: Preferences = {
  theme: 'ink', appearance: 'system', lightAt: 420, darkAt: 1140, source: 'collection',
  difficulty: 'medium', mode: 'challenge', strikeLimit: 3, customEmpty: 45, allowAutofill: false,
  cleanupNotes: false, highlightPeers: true, highlightMatching: true, showTimer: false, haptics: true, sound: true,
};
export function restorePreferences(value: unknown): Preferences {
  const p = { ...defaults };
  if (!value || typeof value !== 'object') return p;
  const raw = value as Record<string, unknown>;
  const enums = { theme: ['ink', 'moss', 'clay'], appearance: ['system', 'light', 'dark', 'scheduled'],
    source: ['collection', 'generated'], difficulty: ['easy', 'medium', 'hard', 'expert', 'custom'], mode: ['challenge', 'classic'] };
  for (const [key, options] of Object.entries(enums)) {
    if (typeof raw[key] === 'string' && options.includes(raw[key] as string)) Object.assign(p, { [key]: raw[key] });
  }
  for (const key of ['allowAutofill', 'cleanupNotes', 'highlightPeers', 'highlightMatching', 'showTimer', 'haptics', 'sound'] as const) {
    if (typeof raw[key] === 'boolean') p[key] = raw[key];
  }
  for (const key of ['lightAt', 'darkAt', 'customEmpty'] as const) {
    if (typeof raw[key] === 'number' && Number.isFinite(raw[key])) {
      p[key] = Math.max(key === 'customEmpty' ? 20 : 0, Math.min(key === 'customEmpty' ? 60 : 1439, Math.round(raw[key])));
    }
  }
  if (Number.isInteger(raw.strikeLimit) && Number(raw.strikeLimit) >= 1 && Number(raw.strikeLimit) <= 5) p.strikeLimit = raw.strikeLimit as number;
  return p;
}
export function darkAppearance(p: Preferences, systemDark: boolean, date = new Date()): boolean {
  if (p.appearance === 'system') return systemDark;
  if (p.appearance !== 'scheduled') return p.appearance === 'dark';
  const now = date.getHours() * 60 + date.getMinutes();
  const light = p.lightAt < p.darkAt ? now >= p.lightAt && now < p.darkAt : now >= p.lightAt || now < p.darkAt;
  return !light;
}
