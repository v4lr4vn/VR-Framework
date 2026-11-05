// Sounds are your own audio files. config/phone.lua -> Sounds gives each event a file path, or false for silence.
let sounds = {};
let prefs = { volume: 0.6, touch: true, silent: false };

export function setSounds(map) {
  sounds = map && typeof map === 'object' ? map : {};
}

// { volume: 0..1, touch: boolean, silent: boolean } from the player's settings.
export function setSoundPrefs(next) {
  prefs = { ...prefs, ...next };
}

// 'notify' is a notification sound (the server already decided if it should play).
// Everything else is a touch sound (the lock click, the hinge) and follows the "touch sounds" setting.
export function play(name) {
  const url = sounds[name];
  if (!url || typeof url !== 'string') return;
  if (prefs.silent) return;
  if (name !== 'notify' && !prefs.touch) return;
  try {
    const audio = new Audio(url);
    audio.volume = Math.max(0, Math.min(1, prefs.volume));
    audio.play().catch(() => {});
  } catch {
    // no sound is better than a broken phone
  }
}

// The ringing phone. It repeats until stopRing(). `url` is the sound file (a path in the html folder).
let ringing = null;

export function startRing(url, volume) {
  stopRing();
  if (!url || typeof url !== 'string' || prefs.silent) return;
  try {
    const audio = new Audio(url);
    audio.loop = true;
    const v = typeof volume === 'number' ? volume : prefs.volume;
    audio.volume = Math.max(0, Math.min(1, v));
    audio.play().catch(() => {});
    ringing = audio;
  } catch {
    ringing = null;
  }
}

export function stopRing() {
  if (!ringing) return;
  try {
    ringing.pause();
  } catch {
    // nothing to stop
  }
  ringing = null;
}
