import { post } from './nui.js';

export const STATS = [
  { key: 'health', icon: 'fa-heart', color: '#FF5A52', label: 'Health', dir: 'low' },
  { key: 'armor', icon: 'fa-shield-halved', color: '#5AA9FF', label: 'Armor', dir: 'high' },
  { key: 'hunger', icon: 'fa-utensils', color: '#FF8A3D', label: 'Hunger', dir: 'low' },
  { key: 'thirst', icon: 'fa-droplet', color: '#4FD1E0', label: 'Thirst', dir: 'low' },
  { key: 'stamina', icon: 'fa-bolt', color: '#3DD68C', label: 'Stamina', dir: 'low' },
  { key: 'oxygen', icon: 'fa-lungs', color: '#9CC3FF', label: 'Oxygen', dir: 'low' },
  { key: 'stress', icon: 'fa-brain', color: '#B79CFF', label: 'Stress', dir: 'high' },
];

const stat = (mode, at) => ({ mode, at });

export const hud = $state({
  visible: false, id: 0, dead: false,
  health: 100, armor: 0, hunger: 100, thirst: 100, stamina: 100, oxygen: 100, stress: 0,
  inVehicle: false, speed: 0, fuel: 100, gear: 'N', engineOn: false, engineHealth: 100, lights: 0,
  left: false, right: false, seatbelt: false, noBelt: false, harness: false, lowFuelAlert: true, gearsUnlocked: false,
  heading: 0, time: '00:00', street: '', postal: '', postalDist: 0,
  voiceIndex: 2, voiceMode: 'Normal', radio: 0, talking: false, radioTalking: false,
});

export const ui = $state({
  ready: false, panel: false, edit: false, voiceModes: 3,
  layout: {},
  settings: {
    stats: {
      health: stat('always', 100), armor: stat('auto', 1), hunger: stat('auto', 50), thirst: stat('auto', 50),
      stamina: stat('auto', 95), oxygen: stat('auto', 95), stress: stat('auto', 30),
    },
    mapOnFoot: false, compassOnFoot: false, postal: true, unit: 'mph', gears: true,
  },
});

const SAMPLE = {
  inVehicle: true, speed: 100, fuel: 58, gear: '3', engineOn: true, engineHealth: 100, lights: 1,
  seatbelt: false, noBelt: false, gearsUnlocked: true,
};

export function view() {
  return ui.edit && !hud.inVehicle ? { ...hud, ...SAMPLE } : hud;
}

export function statVisible(def) {
  if (ui.edit) return true;
  const m = ui.settings.stats[def.key];
  if (!m || m.mode === 'off') return false;
  if (m.mode === 'always') return true;
  const v = hud[def.key];
  return def.dir === 'low' ? v <= m.at : v >= m.at;
}

export const pinned = (def) => !!ui.layout['stat_' + def.key];

export const showMap = () => hud.inVehicle || ui.settings.mapOnFoot || ui.edit;
export const showCompass = () => hud.inVehicle || ui.settings.compassOnFoot || ui.edit;

let timer;
export function persist() {
  clearTimeout(timer);
  timer = setTimeout(() => {
    post('hud:save', { settings: $state.snapshot(ui.settings), layout: $state.snapshot(ui.layout) });
  }, 300);
}

export function reportMap(el) {
  const r = el.getBoundingClientRect();
  post('hud:map', {
    x: r.left / window.innerWidth,
    y: r.top / window.innerHeight,
    w: r.width / window.innerWidth,
    h: r.height / window.innerHeight,
  });
}
