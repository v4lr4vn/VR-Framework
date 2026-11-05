export const place = (anchor, height = 240, width = null) => {
    const r = anchor.getBoundingClientRect();
    const below = window.innerHeight - r.bottom - 8;
    const up = below < height && r.top > below;
    const s = [`left:${Math.round(r.left)}px`, `width:${Math.round(width || r.width)}px`];
    if (up) s.push(`bottom:${Math.round(window.innerHeight - r.top + 4)}px`, `max-height:${Math.round(Math.min(height, r.top - 12))}px`);
    else s.push(`top:${Math.round(r.bottom + 4)}px`, `max-height:${Math.round(Math.min(height, below))}px`);
    return s.join(';');
};

export const outside = (node, fn) => {
    const handler = (e) => {
        if (!node.contains(e.target)) fn();
    };
    setTimeout(() => document.addEventListener('mousedown', handler, true));
    return { destroy: () => document.removeEventListener('mousedown', handler, true) };
};
