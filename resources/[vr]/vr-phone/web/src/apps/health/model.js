// Health numbers that do not need the screen.

// Beats per minute, estimated from what the player is doing, how stressed and how hurt they are. There is no real heart in the game.
export function heartRate(v, resting = 64) {
  const doing = { rest: 0, walk: 18, run: 48, sprint: 78, swim: 38, vehicle: 4 }[v?.state] ?? 0;
  const stress = (Number(v?.stress) || 0) * 0.35;
  const hurt = (100 - (v?.health ?? 100)) * 0.4;
  return Math.round(Math.min(190, resting + doing + stress + hurt));
}

// Moves a shown number toward the target, so the heart rate eases instead of jumping.
export function ease(current, target, amount = 0.35) {
  if (current == null) return target;
  const next = current + (target - current) * amount;
  return Math.abs(target - next) < 0.6 ? target : next;
}

export function distanceText(metres, imperial) {
  if (imperial) {
    const mi = metres / 1609.344;
    return `${mi.toFixed(mi < 10 ? 2 : 1)} mi`;
  }
  const km = metres / 1000;
  return `${km.toFixed(km < 10 ? 2 : 1)} km`;
}

export function activeText(seconds) {
  const m = Math.floor(seconds / 60);
  if (m < 60) return `${m} min`;
  return `${Math.floor(m / 60)} h ${m % 60} min`;
}

// 0..1 for the progress ring.
export const progress = (steps, goal) => Math.max(0, Math.min(1, goal > 0 ? steps / goal : 0));

// Round to the nearest 500 for the goal buttons, inside the allowed range.
export function nudgeGoal(goal, delta, range = [1000, 40000]) {
  const next = Math.round((goal + delta) / 500) * 500;
  return Math.max(range[0], Math.min(range[1], next));
}

export const DAY_LETTERS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
// 'YYYY-MM-DD' -> 0 (Sunday) .. 6
export function dayOfWeek(day) {
  const [y, m, d] = String(day).split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d)).getUTCDay();
}
