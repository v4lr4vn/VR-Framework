export const kb = $state({
  open: false,
  mode: 'menu',
  actions: [],
  binds: {},
  categories: [],
  labels: {},
  modLabels: { shift: 'Shift', ctrl: 'Ctrl', alt: 'Alt' },
  blocked: {},
  gta: {},
  command: 'keybinds',
  section: 'essentials',
  search: '',
  capture: null,
  flash: null,
});

export const keyLabel = (vk) => kb.labels[vk] ?? kb.labels[String(vk)] ?? `Key ${vk}`;

export const bindParts = (b) => {
  if (!b || !b.k) return [];
  const parts = [];
  if (b.m) parts.push(kb.modLabels[b.m] ?? b.m);
  parts.push(keyLabel(b.k));
  return parts;
};

export const bindText = (b) => bindParts(b).join(' + ');

export const blockedWhy = (vk) => kb.blocked[vk] ?? kb.blocked[String(vk)] ?? null;

export const gtaUse = (vk) => kb.gta[vk] ?? kb.gta[String(vk)] ?? null;

export const actionById = (id) => kb.actions.find((a) => a.id === id);

export const conflictFor = (id, b) => {
  for (const [other, ob] of Object.entries(kb.binds)) {
    if (other !== id && ob && ob.k === b.k && (ob.m ?? null) === (b.m ?? null)) return other;
  }
  return null;
};

export const essentials = () => kb.actions.filter((a) => a.essential);

export const missing = () => essentials().filter((a) => !kb.binds[a.id]);

export const suggestionFree = (a) => !!a.suggested && !conflictFor(a.id, a.suggested) && !blockedWhy(a.suggested.k);
