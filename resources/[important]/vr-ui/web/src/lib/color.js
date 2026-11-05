const clamp = (n, a, b) => Math.min(b, Math.max(a, n));

export const hsvToRgb = (h, s, v) => {
    const f = (n) => {
        const k = (n + h / 60) % 6;
        return v - v * s * Math.max(0, Math.min(k, 4 - k, 1));
    };
    return [Math.round(f(5) * 255), Math.round(f(3) * 255), Math.round(f(1) * 255)];
};

export const rgbToHsv = (r, g, b) => {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
    let h = 0;
    if (d) {
        if (max === r) h = ((g - b) / d) % 6;
        else if (max === g) h = (b - r) / d + 2;
        else h = (r - g) / d + 4;
        h *= 60;
        if (h < 0) h += 360;
    }
    return [h, max ? d / max : 0, max];
};

export const rgbToHsl = (r, g, b) => {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2, d = max - min;
    let h = 0, s = 0;
    if (d) {
        s = d / (1 - Math.abs(2 * l - 1));
        if (max === r) h = ((g - b) / d) % 6;
        else if (max === g) h = (b - r) / d + 2;
        else h = (r - g) / d + 4;
        h *= 60;
        if (h < 0) h += 360;
    }
    return [Math.round(h), Math.round(s * 100), Math.round(l * 100)];
};

const hslToRgb = (h, s, l) => {
    s /= 100; l /= 100;
    const k = (n) => (n + h / 30) % 12;
    const a = s * Math.min(l, 1 - l);
    const f = (n) => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
    return [Math.round(f(0) * 255), Math.round(f(8) * 255), Math.round(f(4) * 255)];
};

export const parse = (str) => {
    if (typeof str !== 'string') return null;
    const s = str.trim().toLowerCase();
    let m;
    if ((m = s.match(/^#?([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/))) {
        let h = m[1];
        if (h.length <= 4) h = h.split('').map((c) => c + c).join('');
        const n = (i) => parseInt(h.slice(i, i + 2), 16);
        return { r: n(0), g: n(2), b: n(4), a: h.length === 8 ? n(6) / 255 : 1 };
    }
    if ((m = s.match(/^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)(?:[\s,/]+([\d.]+%?))?\s*\)$/))) {
        const a = m[4] === undefined ? 1 : m[4].endsWith('%') ? parseFloat(m[4]) / 100 : parseFloat(m[4]);
        return { r: clamp(+m[1], 0, 255), g: clamp(+m[2], 0, 255), b: clamp(+m[3], 0, 255), a: clamp(a, 0, 1) };
    }
    if ((m = s.match(/^hsla?\(\s*([\d.]+)(?:deg)?[\s,]+([\d.]+)%[\s,]+([\d.]+)%(?:[\s,/]+([\d.]+%?))?\s*\)$/))) {
        const [r, g, b] = hslToRgb(+m[1], +m[2], +m[3]);
        const a = m[4] === undefined ? 1 : m[4].endsWith('%') ? parseFloat(m[4]) / 100 : parseFloat(m[4]);
        return { r, g, b, a: clamp(a, 0, 1) };
    }
    return null;
};

const hex2 = (n) => Math.round(n).toString(16).padStart(2, '0');

export const format = ({ r, g, b, a }, fmt = 'hex') => {
    const al = Math.round(a * 100) / 100;
    switch (fmt) {
        case 'hexa': return `#${hex2(r)}${hex2(g)}${hex2(b)}${hex2(a * 255)}`;
        case 'rgb': return `rgb(${r}, ${g}, ${b})`;
        case 'rgba': return `rgba(${r}, ${g}, ${b}, ${al})`;
        case 'hsl': { const [h, s, l] = rgbToHsl(r, g, b); return `hsl(${h}, ${s}%, ${l}%)`; }
        case 'hsla': { const [h, s, l] = rgbToHsl(r, g, b); return `hsla(${h}, ${s}%, ${l}%, ${al})`; }
        default: return `#${hex2(r)}${hex2(g)}${hex2(b)}`;
    }
};

export const hasAlpha = (fmt) => fmt === 'rgba' || fmt === 'hsla' || fmt === 'hexa';
