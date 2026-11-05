// The stopwatch lives here, not in the screen, so it keeps running while you look at another app.
export const watch = $state({ running: false, base: 0, startedAt: 0, laps: [] });

export function elapsed(now = Date.now()) {
  return watch.base + (watch.running ? now - watch.startedAt : 0);
}

export function toggle() {
  if (watch.running) {
    watch.base = elapsed();
    watch.running = false;
  } else {
    watch.startedAt = Date.now();
    watch.running = true;
  }
}

export function lap() {
  if (!watch.running) return;
  const total = elapsed();
  const last = watch.laps.length ? watch.laps[0].total : 0;
  watch.laps = [{ n: watch.laps.length + 1, total, split: total - last }, ...watch.laps].slice(0, 30);
}

export function reset() {
  watch.running = false;
  watch.base = 0;
  watch.laps = [];
}

// 01:23.45
export function format(ms) {
  const total = Math.floor(ms / 10);
  const cs = String(total % 100).padStart(2, '0');
  const s = String(Math.floor(total / 100) % 60).padStart(2, '0');
  const m = String(Math.floor(total / 6000)).padStart(2, '0');
  return `${m}:${s}.${cs}`;
}
