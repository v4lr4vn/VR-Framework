const STYLES = ['fas', 'far', 'fab', 'fa-solid', 'fa-regular', 'fa-brands'];
const SWAP = { fal: 'fa-solid', fad: 'fa-solid', fat: 'fa-solid', 'fa-light': 'fa-solid', 'fa-duotone': 'fa-solid', 'fa-thin': 'fa-solid', 'fa-sharp': '' };
const ANIM = {
    spin: 'fa-spin', spinPulse: 'fa-spin-pulse', spinReverse: 'fa-spin-reverse', pulse: 'fa-spin-pulse',
    beat: 'fa-beat', fade: 'fa-fade', beatFade: 'fa-beat-fade', bounce: 'fa-bounce', shake: 'fa-shake',
};
const IMAGE = /^(https?:\/\/|nui:\/\/|data:image\/)|\.(png|jpe?g|webp|gif|svg)$/i;

export const iconOf = (icon, animation) => {
    if (!icon) return null;
    if (Array.isArray(icon)) icon = `${icon[0] || 'fas'} fa-${icon[1]}`;
    if (typeof icon !== 'string') return null;
    icon = icon.trim();
    if (!icon) return null;
    if (IMAGE.test(icon)) return { img: icon };
    let parts = icon.split(/\s+/).map((p) => (p in SWAP ? SWAP[p] : p)).filter(Boolean);
    if (!parts.some((p) => p.startsWith('fa-') && !STYLES.includes(p))) {
        const last = parts.pop();
        parts.push(`fa-${last}`);
    }
    if (!parts.some((p) => STYLES.includes(p))) parts.unshift('fa-solid');
    if (animation && ANIM[animation]) parts.push(ANIM[animation]);
    return { cls: parts.join(' ') };
};

const NAMED = {
    white: '#E6EDF5', red: '#FF5A52', green: '#3DD68C', blue: '#5AA9FF', yellow: '#F5A524', orange: '#FF8A3D',
    pink: '#FF6F91', purple: '#B79CFF', grape: '#B79CFF', violet: '#B79CFF', cyan: '#4FD1E0', teal: '#3DD6C3',
    lime: '#A6E05A', indigo: '#7C8CFF', gray: '#8A9AB0', grey: '#8A9AB0', dark: '#6F8099',
};

export const colorOf = (value, fallback) => {
    if (!value || typeof value !== 'string') return fallback;
    const v = value.trim();
    if (NAMED[v.toLowerCase()]) return NAMED[v.toLowerCase()];
    if (/^#[0-9a-f]{3,8}$/i.test(v) || /^(rgb|rgba|hsl|hsla)\([\d\s.,%]+\)$/i.test(v)) return v;
    return fallback;
};
