const handlers = new Map();

export const on = (action, fn) => {
    if (!handlers.has(action)) handlers.set(action, new Set());
    handlers.get(action).add(fn);
    return () => handlers.get(action).delete(fn);
};

export const emit = (action, data) => {
    const set = handlers.get(action);
    if (set) for (const fn of set) fn(data);
};

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg !== 'object' || typeof msg.action !== 'string') return;
    emit(msg.action, msg.data);
});
