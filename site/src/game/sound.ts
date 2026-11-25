import type { Cue } from './machine';

let audio: AudioContext | undefined;
// Unlock in the originating key/touch gesture, before the flight animation.
export function armSound() {
  try {
    audio ??= new AudioContext();
    if (audio.state !== 'running') void audio.resume().catch(() => {});
  } catch { /* Audio is optional on restricted browsers. */ }
}
export function playSound(cue: Cue) {
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
  if (cue === 'correct') {
    tone(0, 455, 490, .095, .085, 'triangle');
    tone(.065, 640, 720, .14, .065, 'sine');
  } else tone(0, 260, 116, .17, .11, 'sine');
}
