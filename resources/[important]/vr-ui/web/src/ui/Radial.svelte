<script>
  import { onMount } from 'svelte';
  import { on } from '../lib/bus.js';
  import { post } from '../lib/nui.js';
  import { settings } from '../lib/settings.svelte.js';
  import { plain } from '../lib/md.js';
  import Icon from './Icon.svelte';
  import Glyph from './Glyph.svelte';

  let radial = $state(null);
  let page = $state(0);
  let hover = $state(-1);

  const PER = 8;

  const pages = $derived.by(() => {
    const items = (radial?.items || []).map((it, i) => ({ ...it, index: i + 1 }));
    if (items.length <= PER) return [items];
    const out = [];
    for (let i = 0; i < items.length; i += PER - 1) out.push(items.slice(i, i + PER - 1));
    return out.map((p) => [...p, { more: true, label: 'More', icon: 'ellipsis' }]);
  });
  const shown = $derived(pages[page] || []);

  const shift = (i, n) => (n > 1 ? Math.round(Math.sin(((i + 0.5) / n) * Math.PI) * 26) : 0);

  const pick = (it) => {
    if (!it) return;
    if (it.more) {
      page = (page + 1) % pages.length;
      hover = -1;
      return;
    }
    post('radial:select', { index: it.index });
  };

  const middle = () => post(radial?.sub ? 'radial:back' : 'radial:close', {});

  const onKey = (e) => {
    if (e.defaultPrevented || !radial) return;
    if (e.key === 'Escape') post('radial:close', {});
    else if (e.key === 'Backspace' && radial.sub) post('radial:back', {});
    else if (e.key === 'ArrowDown') hover = (hover + 1) % shown.length;
    else if (e.key === 'ArrowUp') hover = (hover - 1 + shown.length) % shown.length;
    else if (e.key === 'Enter' && hover >= 0) pick(shown[hover]);
    else if (/^[1-9]$/.test(e.key)) pick(shown[Number(e.key) - 1]);
  };

  onMount(() => {
    const a = on('radial:open', (d) => {
      radial = d;
      page = Math.max(0, Number(d?.page) || 0);
      hover = -1;
    });
    const b = on('radial:close', () => (radial = null));
    window.addEventListener('keydown', onKey);
    return () => (a(), b(), window.removeEventListener('keydown', onKey));
  });
</script>

{#if radial}
  <div class="radial" style:left="{(settings.radial.x ?? 0.24) * 100}vw" style:top="{(settings.radial.y ?? 0.24) * 100}vh" oncontextmenu={(e) => { e.preventDefault(); middle(); }} role="menu" tabindex="-1">
    <button class="hub card" onclick={middle} aria-label={radial.sub ? 'Back' : 'Close'}>
      <span class="hbtn"><Glyph name={radial.sub ? 'back' : 'close'} size={14} /></span>
      <span class="ttl">{plain(radial.title || (radial.sub ? 'Back' : 'Menu'))}</span>
      {#if pages.length > 1}<span class="pg mono">{page + 1}/{pages.length}</span>{/if}
    </button>

    <div class="list">
      {#key `${radial.title}|${radial.sub}|${page}`}
        {#each shown as it, i (i)}
          <button
            class="opt card"
            class:hot={hover === i}
            style:--x="{shift(i, shown.length)}px"
            style:--i={i}
            role="menuitem"
            onmouseenter={() => (hover = i)}
            onmouseleave={() => (hover = -1)}
            onclick={() => pick(it)}
          >
            <span class="ico">{#if it.icon}<Icon icon={it.icon} size={15} />{/if}</span>
            <span class="lbl">{plain(it.label || '')}</span>
            {#if it.hasMenu}<span class="chev"><Glyph name="chevron" size={14} /></span>{/if}
            {#if !it.more}<kbd class="key">{i + 1}</kbd>{/if}
          </button>
        {/each}
      {/key}
      {#if shown.length === 0}
        <div class="empty card">No actions available</div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .radial { position: fixed; width: 252px; transform: translate(-50%, -24px); z-index: 50; pointer-events: auto; outline: none; animation: pop 0.16s var(--ease); }

  .hub { position: relative; display: flex; align-items: center; gap: 10px; width: 100%; height: 48px; padding: 0 12px 0 14px; text-align: left; color: var(--text); overflow: hidden; }
  .hub::before { content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: var(--accent); }
  .hub:hover { border-color: var(--accent-line); }
  .hbtn { flex: none; width: 26px; height: 26px; display: inline-flex; align-items: center; justify-content: center; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); }
  .hub:hover .hbtn { border-color: var(--accent-line); color: var(--accent-2); }
  .ttl { flex: 1; min-width: 0; font-size: 16px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .pg { flex: none; font-size: 11px; color: var(--p2-text); }
  .mono { font-family: var(--mono); }

  .list { position: relative; display: flex; flex-direction: column; gap: 5px; margin-top: 7px; }
  .list::before { content: ''; position: absolute; left: 17px; top: -7px; bottom: 22px; width: 2px; background: linear-gradient(var(--accent-line), transparent); border-radius: 2px; }

  .opt {
    position: relative; display: flex; align-items: center; gap: 11px; width: 100%; height: 48px; padding: 0 10px;
    margin-left: var(--x); width: calc(100% - 26px); text-align: left; color: var(--text); box-shadow: 0 6px 16px rgba(0, 0, 0, 0.4);
    opacity: 0; animation: drop 0.26s var(--ease) forwards; animation-delay: calc(var(--i) * 38ms);
    transition: background 0.1s, border-color 0.1s, margin-left 0.12s;
  }
  .opt.hot { background: var(--panel-2); border-color: var(--line-3); margin-left: calc(var(--x) + 6px); }
  .opt.hot::before { content: ''; position: absolute; left: -1px; top: 8px; bottom: 8px; width: 3px; border-radius: 2px; background: var(--accent); }
  .ico { flex: none; width: 30px; height: 30px; display: inline-flex; align-items: center; justify-content: center; border-radius: 6px; background: var(--panel); border: 1px solid var(--line-2); color: var(--text-2); }
  .opt.hot .ico { border-color: var(--accent-line); background: var(--accent-soft); color: var(--accent-2); }
  .lbl { flex: 1; min-width: 0; font-size: 15px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .chev { flex: none; color: var(--faint); }
  .opt.hot .chev { color: var(--accent); }
  kbd.key { flex: none; margin: 0; }
  .empty { height: 48px; display: flex; align-items: center; padding: 0 14px; margin-left: 26px; width: calc(100% - 26px); color: var(--muted); font-size: 14px; }

  @keyframes pop { from { opacity: 0; } to { opacity: 1; } }
  @keyframes drop { from { opacity: 0; transform: translateY(-12px); } to { opacity: 1; transform: none; } }
  @media (prefers-reduced-motion: reduce) { .opt { animation-duration: 0.01s; animation-delay: 0s; } }
</style>
