import { post } from './nui.js';

export const ui = $state({
    ready: false,
    open: false,
    locale: {},
    items: {},
    imagepath: 'nui://vr-inventory/web/images',
    keys: [],
    player: null,
    right: null,
    amount: 0,
    hotbar: 0,
    meta: {},
    notes: [],
    tooltip: null,
    menu: null,
    drag: null,
    help: false,
    busy: false,
    toast: null,
});

export const t = (key, ...args) => {
    let s = ui.locale[key];
    if (s === undefined || s === null) s = key;
    s = String(s);
    let i = 0;
    return s.replace(/%s|%d/g, () => (i < args.length ? String(args[i++]) : ''));
};

export const itemData = (name) => ui.items[name] || {};

export const labelOf = (item) => {
    if (!item) return '';
    return (item.metadata && item.metadata.label) || itemData(item.name).label || item.label || item.name;
};

const PROTO = /^([a-z]+:\/\/|data:)/i;

export const imageOf = (item) => {
    if (!item) return '';
    const m = item.metadata || {};
    if (typeof m.imageurl === 'string' && m.imageurl) return m.imageurl;
    if (typeof m.image === 'string' && m.image) {
        if (PROTO.test(m.image)) return m.image;
        return `${ui.imagepath}/${/\.\w{3,4}$/.test(m.image) ? m.image : `${m.image}.png`}`;
    }
    const d = itemData(item.name);
    if (d.image) return d.image;
    return `${ui.imagepath}/${item.name}.png`;
};

export const descriptionOf = (item) => (item && item.metadata && item.metadata.description) || itemData(item && item.name).description || item?.description || '';

export const durabilityOf = (item) => {
    const m = item && item.metadata;
    if (!m || typeof m.durability !== 'number') return null;
    const d = m.durability;
    if (d > 100) {
        const degrade = Number(m.degrade) || 0;
        if (!degrade) return 100;
        const left = d - Date.now() / 1000;
        return Math.max(0, Math.min(100, (left / (degrade * 60)) * 100));
    }
    return Math.max(0, Math.min(100, d));
};

export const normaliseInventory = (inv, fallbackId) => {
    if (!inv) return null;
    const slots = Math.max(1, Number(inv.slots) || 1);
    const list = new Array(slots).fill(null);
    const raw = Array.isArray(inv.items) ? inv.items : inv.items && typeof inv.items === 'object' ? Object.values(inv.items) : [];
    for (const item of raw) {
        if (!item || !item.slot) continue;
        const idx = Number(item.slot) - 1;
        if (idx >= 0 && idx < slots) list[idx] = item.name ? item : null;
    }
    const out = {
        id: inv.id ?? fallbackId,
        type: inv.type || 'stash',
        label: inv.label ?? '',
        slots,
        weight: Number(inv.weight) || 0,
        maxWeight: Number(inv.maxWeight) || 0,
        items: list,
        index: inv.index,
        groups: inv.groups,
    };
    if (out.type !== 'shop' && out.type !== 'crafting') out.weight = sumWeight(out);
    return out;
};

export const sumWeight = (inv) => {
    let total = 0;
    for (const item of inv.items) if (item && typeof item.weight === 'number') total += item.weight;
    return total;
};

const sameId = (a, b) => a !== undefined && a !== null && b !== undefined && b !== null && String(a) === String(b);

export const findInventory = (id) => {
    if (id === 'player' || (ui.player && sameId(ui.player.id, id))) return ui.player;
    if (ui.right && (sameId(ui.right.id, id) || (id === 'shop' && ui.right.type === 'shop'))) return ui.right;
    return null;
};

export const applySlots = (data) => {
    if (!data) return;
    if (Array.isArray(data.items)) {
        for (const entry of data.items) {
            if (!entry || !entry.item) continue;
            const inv = findInventory(entry.inventory ?? 'player');
            if (!inv) continue;
            const slot = Number(entry.item.slot);
            if (!slot || slot < 1) continue;
            if (slot > inv.items.length) {
                if (slot > 500) continue;
                while (inv.items.length < slot) inv.items.push(null);
            }
            inv.items[slot - 1] = entry.item.name ? entry.item : null;
            if (inv.type !== 'shop' && inv.type !== 'crafting') inv.weight = sumWeight(inv);
        }
    }
    if (data.itemCount && typeof data.itemCount === 'object') {
        for (const [name, diff] of Object.entries(data.itemCount)) {
            const d = ui.items[name];
            if (d) d.count = (d.count || 0) + Number(diff || 0);
        }
    }
    if (data.weightData) {
        const inv = findInventory(data.weightData.inventoryId);
        if (inv) inv.maxWeight = Number(data.weightData.maxWeight) || inv.maxWeight;
    }
    if (data.slotsData) {
        const inv = findInventory(data.slotsData.inventoryId);
        const slots = Number(data.slotsData.slots);
        if (inv && slots > 0 && slots <= 500) {
            if (slots > inv.items.length) while (inv.items.length < slots) inv.items.push(null);
            else inv.items.length = slots;
            inv.slots = slots;
        }
    }
};

export const counts = () => {
    const out = {};
    if (!ui.player) return out;
    for (const item of ui.player.items) if (item) out[item.name] = (out[item.name] || 0) + item.count;
    return out;
};

export const formatWeight = (grams) => {
    const g = Math.max(0, Number(grams) || 0);
    if (g < 1000) return `${Math.round(g)}g`;
    const kg = g / 1000;
    return `${kg >= 100 ? Math.round(kg) : kg.toFixed(kg >= 10 ? 1 : 2).replace(/\.?0+$/, '')}kg`;
};

export const formatKg = (grams) => (Math.max(0, Number(grams) || 0) / 1000).toFixed(1);

export const groupDigits = (n) => String(Math.floor(Number(n) || 0)).replace(/\B(?=(\d{3})+(?!\d))/g, ',');

export const priceOf = (item) => {
    if (!item || item.price === undefined) return '';
    const currency = item.currency || 'money';
    if (currency === 'money') return `${t('$')}${groupDigits(item.price)}`;
    return `${groupDigits(item.price)} ${itemData(currency).label || currency}`;
};

export const sameMeta = (a, b) => {
    const ea = !a || (Array.isArray(a) ? a.length === 0 : Object.keys(a).length === 0);
    const eb = !b || (Array.isArray(b) ? b.length === 0 : Object.keys(b).length === 0);
    if (ea && eb) return true;
    return JSON.stringify(sortKeys(a)) === JSON.stringify(sortKeys(b));
};

const sortKeys = (v) => {
    if (Array.isArray(v)) return v.map(sortKeys);
    if (v && typeof v === 'object') {
        const out = {};
        for (const k of Object.keys(v).sort()) out[k] = sortKeys(v[k]);
        return out;
    }
    return v;
};

export const stackable = (item) => {
    const d = itemData(item.name);
    if (d.stack !== undefined) return d.stack !== false;
    return item.stack !== false;
};

const TYPES = {
    player: { tone: 'accent', icon: 'user', code: 'POCKETS' },
    otherplayer: { tone: 'danger', icon: 'hand', code: 'SEARCH' },
    stash: { tone: 'info', icon: 'warehouse', code: 'STASH' },
    temp: { tone: 'info', icon: 'box-open', code: 'STASH' },
    policeevidence: { tone: 'info', icon: 'box-archive', code: 'EVIDENCE' },
    trunk: { tone: 'warn', icon: 'car-rear', code: 'TRUNK' },
    glovebox: { tone: 'warn', icon: 'car', code: 'GLOVEBOX' },
    drop: { tone: 'muted', icon: 'location-dot', code: 'DROP' },
    newdrop: { tone: 'muted', icon: 'location-dot', code: 'GROUND' },
    shop: { tone: 'ok', icon: 'basket-shopping', code: 'SHOP' },
    crafting: { tone: 'doj', icon: 'screwdriver-wrench', code: 'BENCH' },
    container: { tone: 'accent', icon: 'bag-shopping', code: 'BAG' },
    dumpster: { tone: 'muted', icon: 'dumpster', code: 'DUMPSTER' },
    inspect: { tone: 'doj', icon: 'eye', code: 'VIEW' },
};

export const typeInfo = (type) => TYPES[type] || TYPES.stash;

export const titleOf = (inv) => {
    if (!inv) return '';
    if (inv.type === 'newdrop') return t('ui_ground');
    if (inv.type === 'player' || inv.id === 'player') return inv.label || t('ui_pockets');
    return inv.label || typeInfo(inv.type).code;
};

export const readOnly = (inv) => !inv || inv.type === 'inspect';

export const closeInventory = () => {
    ui.menu = null;
    ui.tooltip = null;
    ui.drag = null;
    post('exit');
};
