<script>
  import { onMount, tick } from 'svelte';
  import { on } from '../lib/bus.js';
  import { post } from '../lib/nui.js';
  import { md, plain } from '../lib/md.js';
  import { colorOf } from '../lib/icon.js';
  import { settings } from '../lib/settings.svelte.js';
  import Icon from './Icon.svelte';
  import Glyph from './Glyph.svelte';

  let menu = $state(null);
  let selected = $state(0);
  let scrolls = $state({});
  let checks = $state({});
  let listEl = $state();

  const POS = ['top-left', 'top-right', 'bottom-left', 'bottom-right'];
  const pos = $derived(POS.includes(menu?.position) ? menu.position : settings.menu.position || 'top-left');
  const opts = $derived(menu?.options || []);
  const current = $derived(opts[selected]);
  const valueOf = (opt, i) => {
    const v = opt.values?.[(scrolls[i] ?? 1) - 1];
    return v === undefined ? null : typeof v === 'object' && v !== null ? v : { label: String(v) };
  };
  const description = $derived.by(() => {
    if (!current) return '';
    const v = valueOf(current, selected);
    return (v && v.description) || current.description || '';
  });

  const reveal = async () => {
    await tick();
    const el = listEl?.querySelector(`[data-i="${selected}"]`);
    if (el) el.scrollIntoView({ block: 'nearest' });
  };

  const move = (dir) => {
    if (!opts.length) return;
    selected = (selected + dir + opts.length) % opts.length;
    post('menu:move', { id: menu.id, index: selected + 1, scroll: current?.values ? scrolls[selected] ?? 1 : null });
    reveal();
  };

  const side = (dir) => {
    const opt = opts[selected];
    if (!opt?.values?.length) return;
    const n = opt.values.length;
    const cur = scrolls[selected] ?? 1;
    const next = ((cur - 1 + dir + n) % n) + 1;
    scrolls[selected] = next;
    post('menu:scroll', { id: menu.id, index: selected + 1, scroll: next });
  };

  const choose = () => {
    const opt = opts[selected];
    if (!opt) return;
    if (opt.checked !== undefined && opt.checked !== null) {
      checks[selected] = !checks[selected];
      post('menu:check', { id: menu.id, index: selected + 1, checked: checks[selected] });
      return;
    }
    post('menu:select', { id: menu.id, index: selected + 1, scroll: opt.values ? scrolls[selected] ?? 1 : null });
  };

  const close = (key) => {
    if (!menu || menu.canClose === false) return;
    post('menu:close', { id: menu.id, key });
  };

  const onKey = (e) => {
    if (e.defaultPrevented) return;
    if (!menu) return;
    switch (e.key) {
      case 'ArrowUp': move(-1); break;
      case 'ArrowDown': move(1); break;
      case 'ArrowLeft': side(-1); break;
      case 'ArrowRight': side(1); break;
      case 'Enter': choose(); break;
      case 'Escape': case 'Backspace': close(e.key); break;
      default: return;
    }
    e.preventDefault();
  };

  const load = (d, keepIndex) => {
    menu = d;
    const sc = {};
    const ck = {};
    (d.options || []).forEach((o, i) => {
      if (o.values) sc[i] = Math.max(1, Math.min(o.values.length || 1, Number(o.defaultIndex) || 1));
      if (o.checked !== undefined && o.checked !== null) ck[i] = !!o.checked;
    });
    scrolls = sc;
    checks = ck;
    if (!keepIndex) selected = Math.max(0, Math.min((d.options?.length || 1) - 1, (Number(d.startIndex) || 1) - 1));
    reveal();
  };

  onMount(() => {
    const a = on('menu:show', (d) => load(d, false));
    const b = on('menu:update', (d) => {
      if (menu && d && d.id === menu.id) load({ ...menu, ...d }, true);
    });
    const c = on('menu:hide', () => (menu = null));
    window.addEventListener('keydown', onKey);
    return () => (a(), b(), c(), window.removeEventListener('keydown', onKey));
  });
</script>

{#if menu}
  <section class="lm {pos} card">
    <header>
      <h2>{plain(menu.title || '')}</h2>
      <span class="count">{opts.length ? selected + 1 : 0}/{opts.length}</span>
    </header>
    <div class="list scroll" bind:this={listEl}>
      {#each opts as opt, i}
        {@const v = opt.values ? valueOf(opt, i) : null}
        <div class="row" class:sel={i === selected} data-i={i}>
          {#if opt.icon}
            <span class="ico" style:color={colorOf(opt.iconColor, null)}><Icon icon={opt.icon} animation={opt.iconAnimation} size={14} /></span>
          {/if}
          <span class="label">{plain(opt.label || '')}</span>
          {#if opt.values}
            <span class="vals">
              <span class="arrow"><Glyph name="left" size={13} /></span>
              <span class="val">{plain(v?.label ?? '')}</span>
              <span class="arrow"><Glyph name="right" size={13} /></span>
            </span>
          {:else if opt.checked !== undefined && opt.checked !== null}
            <span class="box" class:on={checks[i]}>{#if checks[i]}<Glyph name="check" size={12} stroke={3} />{/if}</span>
          {/if}
        </div>
      {/each}
    </div>
    {#if description}
      <footer class="md">{@html md(description)}</footer>
    {/if}
    <div class="keys">
      <span><kbd class="key">↑</kbd><kbd class="key">↓</kbd> Move</span>
      {#if current?.values}<span><kbd class="key">←</kbd><kbd class="key">→</kbd> Change</span>{/if}
      <span><kbd class="key">↵</kbd> Select</span>
      {#if menu.canClose !== false}<span><kbd class="key">ESC</kbd> Close</span>{/if}
    </div>
  </section>
{/if}

<style>
  .lm { position: fixed; width: 340px; z-index: 45; display: flex; flex-direction: column; overflow: hidden; pointer-events: none; animation: drop 0.18s var(--ease); }
  .top-left { top: 24px; left: 24px; }
  .top-right { top: 24px; right: 24px; }
  .bottom-left { bottom: 24px; left: 24px; }
  .bottom-right { bottom: 24px; right: 24px; }

  header { position: relative; display: flex; align-items: center; gap: 10px; padding: 12px 14px; border-bottom: 1px solid var(--line); }
  header::before { content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: var(--accent); }
  h2 { flex: 1; min-width: 0; font-size: 16px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .count { font-family: var(--mono); font-size: 12px; font-weight: 600; color: var(--p2-text); }

  .list { max-height: 360px; padding: 6px; display: flex; flex-direction: column; gap: 3px; }
  .row { position: relative; display: flex; align-items: center; gap: 10px; min-height: 40px; padding: 6px 10px; border-radius: var(--radius); border: 1px solid transparent; color: var(--text-2); }
  .row.sel { background: var(--accent-soft); border-color: var(--accent-line); color: var(--text); }
  .row.sel::before { content: ''; position: absolute; left: -1px; top: 8px; bottom: 8px; width: 3px; border-radius: 2px; background: var(--accent); }
  .ico { flex: none; width: 26px; height: 26px; display: inline-flex; align-items: center; justify-content: center; border-radius: 6px; background: var(--panel); border: 1px solid var(--line-2); color: var(--text-2); }
  .row.sel .ico { color: var(--accent-2); border-color: var(--accent-line); }
  .label { flex: 1; min-width: 0; font-size: 15px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .vals { flex: none; display: inline-flex; align-items: center; gap: 4px; max-width: 55%; }
  .val { font-family: var(--mono); font-size: 13px; font-weight: 600; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .arrow { color: var(--faint); display: inline-flex; }
  .row.sel .arrow { color: var(--accent); }
  .box { flex: none; width: 18px; height: 18px; border-radius: 4px; border: 1px solid var(--line-3); background: var(--bg-2); display: inline-flex; align-items: center; justify-content: center; color: var(--accent-ink); }
  .box.on { background: var(--accent); border-color: var(--accent); }

  footer { padding: 10px 14px; border-top: 1px solid var(--line); color: var(--muted); font-size: 13px; line-height: 1.4; }
  .keys { display: flex; flex-wrap: wrap; gap: 10px; padding: 8px 12px; border-top: 1px solid var(--line); background: rgba(10, 14, 20, 0.5); color: var(--faint); font-size: 12px; }
  .keys span { display: inline-flex; align-items: center; gap: 2px; }
  .keys :global(kbd.key) { height: 18px; min-width: 18px; font-size: 11px; padding: 0 4px; }

  @keyframes drop { from { opacity: 0; translate: 0 -6px; } to { opacity: 1; translate: 0 0; } }
</style>
