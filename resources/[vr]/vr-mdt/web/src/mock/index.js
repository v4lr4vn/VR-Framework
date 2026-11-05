import { mockState } from './state.js';

const handlers = new Map();
const callbacks = new Map();

function reg(action, fn) {
  if (!handlers.has(action)) handlers.set(action, []);
  handlers.get(action).push(fn);
}

function regCallback(name, fn) {
  if (!callbacks.has(name)) callbacks.set(name, []);
  callbacks.get(name).unshift(fn);
}

const modules = import.meta.glob('./modules/*.js', { eager: true });
for (const m of Object.values(modules)) m.default?.(reg, regCallback, mockState);

function keyOf(row) {
  if (!row || typeof row !== 'object') return null;
  return row.cid ?? row.plate ?? row.serial ?? row.id ?? null;
}

function merge(results) {
  const seen = new Map();
  const out = [];
  for (const list of results) {
    for (const row of list) {
      const k = keyOf(row);
      if (k == null) {
        out.push(row);
      } else if (seen.has(k)) {
        const prev = seen.get(k);
        for (const [f, v] of Object.entries(row)) if (prev[f] == null && v != null) prev[f] = v;
      } else {
        const copy = { ...row };
        seen.set(k, copy);
        out.push(copy);
      }
    }
  }
  return out;
}

function run(list, data) {
  if (list.length === 1) return list[0](structuredClone(data), mockState);
  const results = list.map((fn) => fn(structuredClone(data), mockState));
  const good = results.filter((r) => r !== undefined && !(r && r.__error));
  if (good.length && good.every(Array.isArray)) return merge(good);
  return good.length ? good[good.length - 1] : results.find((r) => r && r.__error);
}

export async function mockRequest(action, data) {
  await new Promise((r) => setTimeout(r, 60));
  const list = handlers.get(action);
  if (!list) return { ok: false, error: 'bad_request' };
  try {
    const out = run(list, data ?? {});
    if (out && out.__error) return { ok: false, error: out.__error };
    return { ok: true, data: structuredClone(out) };
  } catch (err) {
    console.error(action, err);
    return { ok: false, error: 'server_error' };
  }
}

export async function mockCallback(name, data) {
  const list = callbacks.get(name);
  if (!list) return { ok: true };
  let last;
  for (const fn of list) {
    const res = await fn(data, mockState);
    if (res === undefined) continue;
    if (res && res.ok) return res;
    last ??= res;
  }
  return last ?? { ok: false, error: 'not_found' };
}

export function fail(error) {
  return { __error: error };
}
