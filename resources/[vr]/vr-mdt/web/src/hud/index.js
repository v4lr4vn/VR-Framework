const modules = import.meta.glob('./*Hud.svelte', { eager: true });

export const hudComponents = Object.values(modules).map((m) => m.default);
