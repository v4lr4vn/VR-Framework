const subs = new Set();

export const bus = {
  on(fn) {
    subs.add(fn);
    return () => subs.delete(fn);
  },
  emit(d) {
    for (const fn of [...subs]) fn(d);
  },
};
