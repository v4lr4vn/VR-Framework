// Animations can be turned off in Settings, and Low Power Mode turns them off too.
// CSS animations are stopped by a rule in styles/base.css (the `reduce` class on the root).
// Svelte transitions run in JavaScript, so they ask here for their length: fly(node, { duration: dur(260) }).
import { phone } from './store.svelte.js';

export function reduced() {
  return phone.settings.perf.reduceMotion === true || phone.status.lowPower === true;
}

export const dur = (ms) => (reduced() ? 0 : ms);
