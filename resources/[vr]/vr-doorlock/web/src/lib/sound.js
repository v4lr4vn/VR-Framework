const cache = new Map();

export const play = (name, volume = 1) => {
    if (!name) return;
    let base = cache.get(name);
    if (!base) {
        base = new Audio(`./sounds/${name}.wav`);
        cache.set(name, base);
    }
    const a = base.cloneNode();
    a.volume = Math.max(0, Math.min(1, Number(volume) || 0));
    a.play().catch(() => {});
};
