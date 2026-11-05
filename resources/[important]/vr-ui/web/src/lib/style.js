export const cssOf = (style) => {
    if (!style || typeof style !== 'object') return '';
    return Object.entries(style)
        .filter(([k, v]) => /^[a-zA-Z-]+$/.test(k) && (typeof v === 'string' || typeof v === 'number') && !/url\s*\(|expression\s*\(/i.test(String(v)))
        .map(([k, v]) => `${k.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}:${typeof v === 'number' && !/opacity|z-index|font-weight|flex|line-height/.test(k) ? `${v}px` : v}`)
        .join(';');
};
