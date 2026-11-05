export const ROW = 46;

export const radiusFor = (count) => 120 + Math.pow(count, 0.75) * 26;

const column = (radius, count) => {
    const out = [];
    for (let i = 0; i < count; i++) {
        const offset = (i - (count - 1) / 2) * ROW;
        out.push(Math.asin(Math.max(-0.95, Math.min(0.95, offset / radius))));
    }
    return out;
};

export const place = (items) => {
    const n = items.length;
    if (n === 0) return [];
    if (n <= 2) {
        const out = [{ item: items[0], index: 0, side: 'top', angle: -Math.PI / 2 }];
        if (items[1]) out.push({ item: items[1], index: 1, side: 'bottom', angle: Math.PI / 2 });
        return out;
    }
    const rest = n - 1;
    const per = Math.floor(rest / 2);
    const radius = radiusFor(n);
    const offsets = column(radius, per);
    const out = [{ item: items[0], index: 0, side: 'top', angle: -Math.PI / 2 }];
    for (let i = 0; i < per; i++) out.push({ item: items[1 + i], index: 1 + i, side: 'left', angle: Math.PI - offsets[i] });
    for (let i = 0; i < per; i++) out.push({ item: items[1 + per + i], index: 1 + per + i, side: 'right', angle: offsets[i] });
    if (rest % 2 === 1) out.push({ item: items[n - 1], index: n - 1, side: 'bottom', angle: Math.PI / 2 });
    return out;
};

export const position = (entry, count) => {
    const radius = radiusFor(count);
    if (entry.side === 'top') return { x: 0, y: -Math.max(radius * 0.62, 92) };
    if (entry.side === 'bottom') return { x: 0, y: Math.max(radius * 0.62, 92) };
    return { x: Math.cos(entry.angle) * radius, y: Math.sin(entry.angle) * radius };
};

export const pick = (placed, angle) => {
    let best = -1;
    let bestDelta = Infinity;
    placed.forEach((p, i) => {
        const delta = Math.abs(((p.angle - angle + 3 * Math.PI) % (2 * Math.PI)) - Math.PI);
        if (delta < Math.PI / 4 && delta < bestDelta) {
            bestDelta = delta;
            best = i;
        }
    });
    return best;
};
