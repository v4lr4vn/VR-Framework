const schema = {
  types: [
    { id: 'hack', label: 'Hack terminal', icon: 'fa-terminal', color: [90, 169, 255], radius: false, hint: 'Players connect a laptop here and hack the bank network', fields: [
      { key: 'host', label: 'Host name', kind: 'text', max: 30 }, { key: 'tier', label: 'Security tier', kind: 'number', min: 1, max: 5 },
      { key: 'goal', label: 'Goal', kind: 'choice', options: ['vault', 'alarm'] } ] },
    { id: 'drill', label: 'Lock box', icon: 'fa-screwdriver-wrench', color: [245, 165, 36], radius: false, hint: 'Players drill the box open', fields: [
      { key: 'seconds', label: 'Drill time (s)', kind: 'number', min: 8, max: 180 }, { key: 'difficulty', label: 'Difficulty', kind: 'number', min: 1, max: 3 } ] },
    { id: 'cash', label: 'Cash area', icon: 'fa-money-bill-wave', color: [61, 214, 140], radius: true, hint: 'Players grab cash inside the circle', fields: [
      { key: 'grabs', label: 'Grabs', kind: 'number', min: 1, max: 60 } ] },
    { id: 'gold', label: 'Gold area', icon: 'fa-gem', color: [255, 200, 92], radius: true, hint: 'Players grab gold bars inside the circle', fields: [
      { key: 'grabs', label: 'Grabs', kind: 'number', min: 1, max: 40 } ] },
    { id: 'door', label: 'Vault door', icon: 'fa-door-closed', color: [183, 156, 255], radius: false, hint: 'Opens the doorlock doors', fields: [
      { key: 'doors', label: 'Doors', kind: 'doors', max: 6 }, { key: 'swing', label: 'Opens', kind: 'choice', options: ['forward', 'reverse', 'unlock'] }, { key: 'openSeconds', label: 'Stay open (s)', kind: 'number', min: 0, max: 3600 }, { key: 'made', label: 'Made here', kind: 'doors', max: 6, hidden: true } ] },
  ],
  bank: [
    { key: 'label', label: 'Display name', kind: 'text', max: 40 }, { key: 'enabled', label: 'Enabled', kind: 'bool' },
    { key: 'minPolice', label: 'Police needed', kind: 'number', min: 0, max: 30 }, { key: 'cooldownMinutes', label: 'Cooldown (min)', kind: 'number', min: 0, max: 2880 },
  ],
};

let nextBank = 2;
const banks = [{ id: 1, name: 'fleeca-legion', label: 'Fleeca Legion', enabled: true, minPolice: 0, cooldownMinutes: 60, center: { x: 149, y: -1040, z: 29 }, nextId: 4, elements: [
  { id: 1, type: 'hack', label: 'Hack terminal', x: 148.1, y: -1044.2, z: 29.3, w: 90, r: 1.6, host: 'FLEECA-VAULT-01', tier: 2, goal: 'vault' },
  { id: 2, type: 'door', label: 'Vault door', x: 146.6, y: -1046, z: 29.3, w: 0, r: 2, needs: 1, doors: ['bh-fleeca-legion-2-1', 'fleeca-vault'], made: ['bh-fleeca-legion-2-1'], swing: 'forward', openSeconds: 0 },
  { id: 3, type: 'cash', label: 'Cash area', x: 144, y: -1049, z: 29.3, w: 0, r: 2.5, grabs: 8, needs: 2 },
] }];

const overview = () => banks.map((b) => {
  const counts = {};
  b.elements.forEach((e) => (counts[e.type] = (counts[e.type] || 0) + 1));
  return { id: b.id, name: b.name, label: b.label, enabled: b.enabled, count: b.elements.length, counts, state: 'idle' };
});

export const mockOpen = () => ({ banks: overview(), schema, doors: [{ name: 'fleeca-vault', x: 1, y: 1, z: 1 }, { name: 'fleeca-gate', x: 1, y: 1, z: 1 }], doorlock: true, bank: banks[0], status: { id: 1, state: 'idle', cd: 0, el: {} } });

const detail = (b) => ({ bank: JSON.parse(JSON.stringify(b)), status: { id: b.id, state: 'idle', cd: 0, el: {} }, banks: overview() });

export const mockCreator = async (action, d) => {
  const b = banks.find((x) => x.id === d.id);
  if (action === 'open') return { ok: true, data: { banks: overview() } };
  if (action === 'bank') return b ? { ok: true, data: detail(b) } : { ok: false, error: 'bad_bank' };
  if (action === 'create') {
    const nb = { id: nextBank++, name: d.name, label: d.name, enabled: true, minPolice: 0, cooldownMinutes: 60, center: { x: 0, y: 0, z: 0 }, nextId: 1, elements: [] };
    banks.push(nb);
    return { ok: true, data: detail(nb) };
  }
  if (!b) return { ok: false, error: 'bad_bank' };
  if (action === 'add') {
    const t = schema.types.find((x) => x.id === d.type);
    const el = { id: b.nextId++, type: d.type, label: t.label, x: 1, y: 2, z: 3, w: 0, r: t.radius ? 2.5 : 1.5, doors: [] };
    t.fields.forEach((f) => { if (f.kind === 'number') el[f.key] = f.min || 1; if (f.kind === 'text') el[f.key] = 'HOST'; if (f.kind === 'choice') el[f.key] = f.options[0]; });
    b.elements.push(el);
    return { ok: true, data: { ...detail(b), added: el.id } };
  }
  if (action === 'update') {
    const el = b.elements.find((x) => x.id === d.el);
    if (d.patch.needs === el.id) return { ok: false, error: 'needs_loop' };
    Object.assign(el, d.patch);
    if (el.needs === 0) delete el.needs;
    return { ok: true, data: detail(b) };
  }
  if (action === 'remove') { b.elements.splice(b.elements.findIndex((x) => x.id === d.el), 1); return { ok: true, data: detail(b) }; }
  if (action === 'bankset') { Object.assign(b, d.patch); return { ok: true, data: detail(b) }; }
  if (action === 'delete') { banks.splice(banks.indexOf(b), 1); return { ok: true, data: { banks: overview() } }; }
  return { ok: true, data: detail(b) };
};

export const mockTerminal = () => ({ host: 'FLEECA-VAULT-01', hostname: 'fleeca-vault-01.lan', ip: '10.14.201.37', tier: 3, seconds: 250, ward: 'Steel Ward', prompt: 'guest@fleeca-vault-01.lan:~$', user: 'ewalker' });

let tr = 0;
export const mockHack = async (cmd) => {
  tr += 12;
  if (cmd === 'clear') return { ok: true, data: { clear: true, lines: [], trace: tr, prompt: 'guest@fleeca-vault-01.lan:~$' } };
  if (cmd === 'exit') return { ok: true, data: { lines: [{ k: 'dim', t: 'logout' }], closed: true } };
  if (cmd === 'burn') return { ok: true, data: { lines: [{ k: 'err', t: '[!] TRACE COMPLETE' }], closed: true, failed: true, trace: 100 } };
  if (cmd === 'help') return { ok: true, data: { lines: [{ k: 'out', t: 'heimdall  fenrir  gungnir  mjolnir  hel' }, { k: 'ok', t: 'ok line', d: 200 }, { k: 'warn', t: 'warn line' }], trace: tr, prompt: 'guest@fleeca-vault-01.lan:~$' } };
  return { ok: true, data: { lines: [{ k: 'err', t: `${cmd}: command not found` }], trace: tr, prompt: 'guest@fleeca-vault-01.lan:~$' } };
};
