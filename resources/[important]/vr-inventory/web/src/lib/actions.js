import { post } from './nui.js';
import { ui, sumWeight, stackable, sameMeta, itemData, t } from './state.svelte.js';

const clone = (v) => (v === null || v === undefined ? v : JSON.parse(JSON.stringify(v)));

const typeFor = (inv) => (inv === ui.player ? 'player' : inv.type);

const unitWeight = (item) => (item.count > 0 ? item.weight / item.count : itemData(item.name).weight || 0);

const recalc = (inv) => {
    if (inv.type !== 'shop' && inv.type !== 'crafting') inv.weight = sumWeight(inv);
};

export const flash = (message) => {
    ui.toast = { message, id: Date.now() };
};

export const firstSlotFor = (inv, item) => {
    if (!inv) return null;
    if (stackable(item)) {
        for (let i = 0; i < inv.items.length; i++) {
            const other = inv.items[i];
            if (other && other.name === item.name && sameMeta(other.metadata, item.metadata)) return i + 1;
        }
    }
    for (let i = 0; i < inv.items.length; i++) if (!inv.items[i]) return i + 1;
    return null;
};

const optimistic = (from, fromSlot, to, toSlot, count) => {
    const a = from.items[fromSlot - 1];
    const b = to.items[toSlot - 1];
    const before = { from: clone(from.items[fromSlot - 1]), to: clone(to.items[toSlot - 1]) };
    if (!a) return null;

    const unit = unitWeight(a);

    if (!b) {
        const moved = { ...clone(a), slot: toSlot, count, weight: unit * count };
        const left = a.count - count;
        from.items[fromSlot - 1] = left > 0 ? { ...a, count: left, weight: unit * left } : null;
        to.items[toSlot - 1] = moved;
    } else if (b.name === a.name && stackable(a) && sameMeta(a.metadata, b.metadata)) {
        const left = a.count - count;
        to.items[toSlot - 1] = { ...b, count: b.count + count, weight: (b.weight || 0) + unit * count };
        from.items[fromSlot - 1] = left > 0 ? { ...a, count: left, weight: unit * left } : null;
    } else {
        to.items[toSlot - 1] = { ...a, slot: toSlot };
        from.items[fromSlot - 1] = { ...b, slot: fromSlot };
    }

    recalc(from);
    if (to !== from) recalc(to);
    return before;
};

const revert = (from, fromSlot, to, toSlot, before) => {
    if (!before) return;
    from.items[fromSlot - 1] = before.from;
    to.items[toSlot - 1] = before.to;
    recalc(from);
    if (to !== from) recalc(to);
};

const fits = (to, item, count, sameInv) => {
    if (sameInv || !to.maxWeight || to.type === 'newdrop' || to.type === 'container') return true;
    return to.weight + unitWeight(item) * count <= to.maxWeight;
};

export const amountFor = (item, half) => {
    if (half) return Math.max(1, Math.floor(item.count / 2));
    const amount = Math.floor(Number(ui.amount) || 0);
    if (amount > 0) return Math.min(amount, item.count);
    return item.count;
};

export const transfer = async (from, fromSlot, to, toSlot, count) => {
    if (!from || !to || ui.busy) return false;
    const item = from.items[fromSlot - 1];
    if (!item) return false;
    if (from === to && fromSlot === toSlot) return false;
    if (from.type === 'inspect' || to.type === 'inspect') return false;

    if (from.type === 'shop') {
        if (to !== ui.player) return false;
        const target = to.items[toSlot - 1];
        if (target && (target.name !== item.name || !stackable(item))) return false;
        ui.busy = true;
        const ok = await post('buyItem', { fromSlot, toSlot, fromType: 'shop', toType: 'player', count: Math.max(1, Math.floor(Number(ui.amount) || 1)) });
        ui.busy = false;
        return ok === true;
    }

    if (from.type === 'crafting') {
        if (to !== ui.player) return false;
        const target = to.items[toSlot - 1];
        if (target && target.name !== item.name) return false;
        post('craftItem', { fromSlot, toSlot, count: Math.max(1, Math.floor(Number(ui.amount) || 1)) });
        return true;
    }

    if (to.type === 'shop' || to.type === 'crafting') return false;

    count = Math.max(1, Math.min(Math.floor(count || item.count), item.count));
    const target = to.items[toSlot - 1];
    const swap = target && !(target.name === item.name && stackable(item) && sameMeta(target.metadata, item.metadata));

    if (!swap && !fits(to, item, count, from === to)) {
        flash(t(to === ui.player ? 'cannot_carry' : 'cannot_carry_other'));
        return false;
    }

    const before = to.type === 'newdrop' ? null : optimistic(from, fromSlot, to, toSlot, swap ? item.count : count);

    ui.busy = true;
    const ok = await post('swapItems', { fromSlot, fromType: typeFor(from), toSlot, toType: typeFor(to), count: swap ? item.count : count });
    ui.busy = false;

    if (ok === false || ok === null) {
        revert(from, fromSlot, to, toSlot, before);
        return false;
    }
    return true;
};

export const quickMove = (from, slot, half) => {
    const other = from === ui.player ? ui.right : ui.player;
    const item = from.items[slot - 1];
    if (!other || !item) return;
    if (other.type === 'shop' || other.type === 'crafting' || other.type === 'inspect') return;
    const toSlot = firstSlotFor(other, item);
    if (!toSlot) return flash(t(other === ui.player ? 'cannot_carry' : 'cannot_carry_other'));
    return transfer(from, slot, other, toSlot, half ? Math.max(1, Math.floor(item.count / 2)) : amountFor(item));
};

export const splitStack = (inv, slot, count) => {
    const item = inv.items[slot - 1];
    if (!item || count < 1 || count >= item.count) return;
    for (let i = 0; i < inv.items.length; i++) {
        if (!inv.items[i]) return transfer(inv, slot, inv, i + 1, count);
    }
};

export const dropToGround = (slot, count) => {
    const ground = ui.right && (ui.right.type === 'newdrop' || ui.right.type === 'drop') ? ui.right : null;
    const item = ui.player && ui.player.items[slot - 1];
    if (!ground || !item) return;
    const toSlot = firstSlotFor(ground, item) || 1;
    return transfer(ui.player, slot, ground, toSlot, count || item.count);
};

export const useSlot = (slot) => post('useItem', slot);

export const giveSlot = (slot, count) => post('giveItem', { slot, count });

export const copyText = (text) => {
    const area = document.createElement('textarea');
    area.value = String(text);
    area.style.position = 'fixed';
    area.style.opacity = '0';
    document.body.appendChild(area);
    area.select();
    try { document.execCommand('copy'); } catch (e) { }
    area.remove();
};
