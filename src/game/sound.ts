import type { Cue } from './machine';

let audio: AudioContext | undefined;
let unlocking: Promise<void> | undefined;
// Unlock in the originating key/touch gesture, before the flight animation.
export function armSound() {
  try {
    audio ??= new AudioContext();
    if (audio.state !== 'running' && !unlocking) {
      unlocking = audio.resume().catch(() => {}).finally(() => { unlocking = undefined; });
    }
  } catch { /* Audio is optional on restricted browsers. */ }
}
export async function playSound(cue: Cue) {
  // Reduce Motion can settle the final digit before the gesture unlock finishes.
  if (unlocking && audio?.state !== 'running') {
    const arrival = performance.now();
    await unlocking;
    if (document.hidden || performance.now() - arrival > 200) return;
  }
  if (!audio || audio.state !== 'running') return;
  const ctx = audio, now = ctx.currentTime;
  function tone(offset: number, from: number, to: number, duration: number, volume: number, type: OscillatorType) {
    const oscillator = ctx.createOscillator(), gain = ctx.createGain(), start = now + offset;
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(from, start);
    oscillator.frequency.exponentialRampToValueAtTime(to, start + duration);
    gain.gain.setValueAtTime(.0001, start);
    gain.gain.exponentialRampToValueAtTime(volume, start + .009);
    gain.gain.exponentialRampToValueAtTime(.0001, start + duration);
    oscillator.connect(gain).connect(ctx.destination);
    oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); };
    oscillator.start(start); oscillator.stop(start + duration);
  }
  if (cue === 'win') {
    // Last tile: two rounded pickups, then a high D over a quiet lower fifth.
    tone(0, 435, 440, .11, .08, 'triangle');
    tone(.10, 550, 554.4, .13, .07, 'sine');
    tone(.22, 584, 587.3, .38, .075, 'sine');
    tone(.22, 390, 392, .32, .042, 'triangle');
  } else if (cue === 'correct') {
    tone(0, 455, 490, .095, .085, 'triangle');
    tone(.065, 640, 720, .14, .065, 'sine');
  } else tone(0, 260, 116, .17, .11, 'sine');
}
