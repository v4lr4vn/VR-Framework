let ctx = null;
let master = null;
let volume = 0.6;
let muted = false;

function load(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function save(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch {
    return false;
  }
  return true;
}

muted = load('vr-cards:muted') === '1';

function ac() {
  if (!ctx) {
    const A = window.AudioContext || window.webkitAudioContext;
    if (!A) return null;
    ctx = new A();
    master = ctx.createGain();
    master.connect(ctx.destination);
  }
  if (ctx.state === 'suspended') ctx.resume();
  master.gain.value = muted ? 0 : volume;
  return ctx;
}

function tone(freq, at, dur, { type = 'sine', gain = 0.18, attack = 0.008, glide = 0 } = {}) {
  const c = ac();
  if (!c) return;
  const t = c.currentTime + at;
  const o = c.createOscillator();
  const g = c.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, t);
  if (glide) o.frequency.exponentialRampToValueAtTime(freq * glide, t + dur);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(gain, t + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g).connect(master);
  o.start(t);
  o.stop(t + dur + 0.05);
}

let noiseBuf = null;
function noise(at, dur, { from = 800, to = 2400, q = 1.2, gain = 0.25, type = 'bandpass' } = {}) {
  const c = ac();
  if (!c) return;
  if (!noiseBuf) {
    noiseBuf = c.createBuffer(1, c.sampleRate * 1.5, c.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  const t = c.currentTime + at;
  const s = c.createBufferSource();
  s.buffer = noiseBuf;
  const f = c.createBiquadFilter();
  f.type = type;
  f.Q.value = q;
  f.frequency.setValueAtTime(from, t);
  f.frequency.exponentialRampToValueAtTime(to, t + dur);
  const g = c.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(gain, t + Math.min(0.03, dur / 3));
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  s.connect(f).connect(g).connect(master);
  s.start(t);
  s.stop(t + dur + 0.05);
}

const N = { C5: 523.25, E5: 659.25, G5: 783.99, A5: 880, B5: 987.77, C6: 1046.5, D6: 1174.66, E6: 1318.5, G6: 1568, A6: 1760, C7: 2093, E7: 2637, G7: 3136 };

function sparkle(at, n = 3, gain = 0.05) {
  const notes = [N.C7, N.E7, N.G7, N.E7, N.C7];
  for (let i = 0; i < n; i++) tone(notes[i % notes.length] * (1 + Math.random() * 0.02), at + i * 0.06, 0.25, { type: 'sine', gain });
}

export const sfx = {
  setVolume(v) {
    volume = Math.max(0, Math.min(1, Number(v) || 0));
    if (master) master.gain.value = muted ? 0 : volume;
  },
  get muted() {
    return muted;
  },
  toggle() {
    muted = !muted;
    save('vr-cards:muted', muted ? '1' : '0');
    if (master) master.gain.value = muted ? 0 : volume;
    return muted;
  },
  tear() {
    noise(0, 0.45, { from: 500, to: 4200, q: 0.7, gain: 0.3 });
    for (let i = 0; i < 6; i++) noise(0.04 + i * 0.05, 0.05, { from: 2500, to: 3500, q: 4, gain: 0.12 });
  },
  deal() {
    noise(0, 0.09, { from: 1800, to: 900, q: 0.8, gain: 0.12 });
  },
  flip() {
    noise(0, 0.2, { from: 700, to: 2600, q: 1.4, gain: 0.22 });
  },
  shake() {
    for (let i = 0; i < 4; i++) noise(i * 0.12, 0.08, { from: 300, to: 500, q: 2, gain: 0.12, type: 'lowpass' });
  },
  reveal(rarity, foil) {
    if (rarity === 'common') tone(N.A5, 0.02, 0.12, { type: 'triangle', gain: 0.06 });
    if (rarity === 'uncommon') {
      tone(N.E6, 0.02, 0.35, { gain: 0.1 });
      tone(N.B5, 0.1, 0.35, { gain: 0.08 });
    }
    if (rarity === 'rare') {
      [N.C6, N.E6, N.G6].forEach((f, i) => tone(f, 0.02 + i * 0.08, 0.5, { gain: 0.12 }));
    }
    if (rarity === 'epic') {
      [N.G5, N.C6, N.E6, N.G6, N.C7].forEach((f, i) => tone(f, 0.02 + i * 0.07, 0.7, { type: 'triangle', gain: 0.13 }));
      noise(0.1, 0.9, { from: 6000, to: 9000, q: 0.5, gain: 0.05, type: 'highpass' });
    }
    if (rarity === 'legendary') {
      tone(55, 0, 1.6, { gain: 0.35, glide: 0.5 });
      [N.C5, N.E5, N.G5, N.C6].forEach((f) => tone(f, 0.05, 2.2, { type: 'sawtooth', gain: 0.035, attack: 0.05 }));
      [N.C5, N.E5, N.G5, N.C6].forEach((f) => tone(f, 0.05, 2.2, { gain: 0.09, attack: 0.04 }));
      [N.C6, N.E6, N.G6, N.C7].forEach((f, i) => tone(f, 0.3 + i * 0.09, 0.9, { type: 'triangle', gain: 0.1 }));
      sparkle(0.8, 5, 0.06);
      noise(0.05, 1.8, { from: 5000, to: 10000, q: 0.4, gain: 0.07, type: 'highpass' });
    }
    if (foil === 'holo') sparkle(0.25, 4, 0.05);
    else if (foil === 'shiny') sparkle(0.2, 2, 0.04);
  },
  coin() {
    tone(N.B5, 0, 0.12, { type: 'square', gain: 0.04 });
    tone(N.E6, 0.08, 0.3, { type: 'square', gain: 0.04 });
  },
  place() {
    noise(0, 0.08, { from: 1200, to: 600, q: 1, gain: 0.1 });
    tone(220, 0, 0.08, { type: 'sine', gain: 0.06 });
  },
};
