export const em = $state({
  ready: false,
  open: false,
  items: [],
  walks: [],
  moods: [],
  tabs: [],
  slots: 10,
  sharedOn: true,
  walksOn: true,
  moodsOn: true,
  delay: 160,
  tab: 'emotes',
  search: '',
  selected: null,
  hover: null,
  preview: true,
  previewWhy: null,
  animals: false,
  state: { slots: [], keys: [], favs: [], walk: false, mood: false, playing: false, cancelKey: '', menuKey: '' },
  variation: 0,
  picker: false,
  capture: null,
  keyData: null,
  request: null,
  toast: null,
});

export const FLAG_INFO = {
  L: { icon: 'rotate', label: 'Loops until you stop it' },
  M: { icon: 'person-walking', label: 'You can walk while doing it' },
  P: { icon: 'box', label: 'Uses a prop' },
  X: { icon: 'wand-sparkles', label: 'Has an effect (press G)' },
  T: { icon: 'stopwatch', label: 'Plays once, then stops' },
  S: { icon: 'person-rays', label: 'Scenario' },
  G: { icon: 'mars', label: 'Male characters only' },
  N: { icon: 'car-burst', label: 'Not in vehicles' },
  V: { icon: 'car', label: 'Only in vehicles' },
  A: { icon: 'triangle-exclamation', label: '18+' },
  W: { icon: 'user-group', label: 'Needs a partner' },
};

export const flagList = (f) => (f || '').split('').filter((c) => FLAG_INFO[c]);

export const itemById = (id) => em.items.find((i) => i.id === id);

export const isFav = (id) => em.state.favs.includes(id);

export const slotOf = (id) => {
  const i = em.state.slots.indexOf(id);
  return i >= 0 ? i + 1 : 0;
};

export const toast = (text, kind = 'info') => {
  const id = Date.now() + Math.random();
  em.toast = { id, text, kind };
  setTimeout(() => { if (em.toast && em.toast.id === id) em.toast = null; }, 2200);
};
