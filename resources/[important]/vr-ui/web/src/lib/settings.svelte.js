export const settings = $state({
    notify: { position: 'top-right', offsetX: 24, offsetY: 24, width: 340, maxVisible: 3, duration: 5000 },
    textui: { position: 'left-center' },
    progress: { position: 'bottom' },
    context: { position: 'right' },
    menu: { position: 'top-left' },
    radial: { x: 0.24, y: 0.24 },
    accent: null,
});

export const applySettings = (data) => {
    if (!data || typeof data !== 'object') return;
    for (const key of Object.keys(settings)) {
        if (data[key] && typeof data[key] === 'object' && typeof settings[key] === 'object' && settings[key] !== null) Object.assign(settings[key], data[key]);
        else if (data[key] !== undefined) settings[key] = data[key];
    }
};
