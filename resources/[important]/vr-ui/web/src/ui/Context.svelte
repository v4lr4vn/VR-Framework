<script>
  import { onMount } from 'svelte';
  import { on } from '../lib/bus.js';
  import { post } from '../lib/nui.js';
  import { md, plain } from '../lib/md.js';
  import { colorOf } from '../lib/icon.js';
  import { settings } from '../lib/settings.svelte.js';
  import Icon from './Icon.svelte';
  import Glyph from './Glyph.svelte';

  let menu = $state(null);
  let hover = $state(-1);
  let tip = $state(null);
  let tipY = $state(0);
  let listEl = $state();
  let rootEl = $state();

  const pos = $derived(['left', 'right', 'center'].includes(menu?.position) ? menu.position : settings.context.position || 'right');

  const metaRows = (meta) => {
    if (!meta) return [];
    if (Array.isArray(meta)) return meta.map((m) => (typeof m === 'object' && m !== null ? m : { label: String(m) }));
    return Object.entries(meta).map(([label, value]) => (typeof value === 'object' && value !== null ? { label, ...value } : { label, value }));
  };

  const close = () => {
    if (!menu || menu.canClose === false) return;
    post('context:close', { id: menu.id });
  };

  const back = () => {
    if (!menu?.hasBack) return;
    post('context:back', { id: menu.id });
  };

  const pick = (opt) => {
    if (!menu || opt.disabled || opt.readOnly) return;
    post('context:select', { id: menu.id, index: opt.index });
  };

  const enter = (opt, event) => {
    hover = opt.index;
    const rows = metaRows(opt.metadata);
    if (rows.length || opt.image) {
      const r = event.currentTarget.getBoundingClientRect();
      const base = rootEl ? rootEl.getBoundingClientRect().top : 0;
      tipY = r.top - base;
      tip = { rows, image: opt.image, title: opt.title };
    } else tip = null;
  };

  const leave = () => {
    hover = -1;
    tip = null;
  };

  const onKey = (e) => {
    if (e.defaultPrevented) return;
    if (!menu) return;
    if (e.key === 'Escape') close();
    else if (e.key === 'Backspace') back();
  };

  onMount(() => {
    const a = on('context:show', (d) => {
      menu = d;
      tip = null;
      hover = -1;
      if (listEl) listEl.scrollTop = 0;
    });
    const b = on('context:hide', () => {
      menu = null;
      tip = null;
    });
    window.addEventListener('keydown', onKey);
    return () => (a(), b(), window.removeEventListener('keydown', onKey));
  });
</script>

{#if menu}
  <section class="ctx {pos}" bind:this={rootEl}>
    <div class="panel card">
      <header>
        {#if menu.hasBack}
          <button class="hbtn" onclick={back} aria-label="Back"><Glyph name="back" size={16} /></button>
        {/if}
        <h2 class="md">{@html md(menu.title || ' ').replace(/^<p>|<\/p>$/g, '')}</h2>
        {#if menu.canClose !== false}
          <button class="hbtn" onclick={close} aria-label="Close"><Glyph name="close" size={14} /></button>
        {/if}
      </header>
      <div class="list scroll" bind:this={listEl}>
        {#each menu.options as opt (opt.index)}
          <button
            class="opt"
            class:disabled={opt.disabled}
            class:ro={opt.readOnly}
            class:hot={hover === opt.index && !opt.disabled && !opt.readOnly}
            disabled={opt.disabled}
            onclick={() => pick(opt)}
            onmouseenter={(e) => enter(opt, e)}
            onmouseleave={leave}
          >
            {#if opt.icon}
              <span class="ico" style:color={colorOf(opt.iconColor, null)}><Icon icon={opt.icon} animation={opt.iconAnimation} size={15} /></span>
            {/if}
            <span class="body">
              <span class="title">{plain(opt.title || '')}</span>
              {#if opt.description}<span class="desc md">{@html md(opt.description)}</span>{/if}
              {#if typeof opt.progress === 'number'}
                <span class="prog"><span style:width="{Math.max(0, Math.min(100, opt.progress))}%" style:background={colorOf(opt.colorScheme, 'var(--accent)')}></span></span>
              {/if}
            </span>
            {#if opt.arrow || opt.menu}<span class="chev"><Glyph name="chevron" size={14} /></span>{/if}
          </button>
        {/each}
      </div>
    </div>
    {#if tip}
      <aside class="tip card" style:top="{tipY}px">
        {#if tip.image}<img src={tip.image} alt="" />{/if}
        {#each tip.rows as row}
          <div class="mrow">
            <span class="ml">{plain(row.label ?? '')}</span>
            {#if row.value !== undefined && row.value !== null}<span class="mv">{plain(row.value)}</span>{/if}
          </div>
          {#if typeof row.progress === 'number'}
            <span class="prog"><span style:width="{Math.max(0, Math.min(100, row.progress))}%" style:background={colorOf(row.colorScheme, 'var(--accent)')}></span></span>
          {/if}
        {/each}
      </aside>
    {/if}
  </section>
{/if}

<style>
  .ctx { position: fixed; top: 50%; transform: translateY(-50%); z-index: 50; pointer-events: auto; animation: slide 0.18s var(--ease); }
  .ctx.right { right: 20vw; }
  .ctx.left { left: 20vw; }
  .ctx.center { left: 50%; transform: translate(-50%, -50%); }

  .panel { width: 330px; display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 8px; padding: 12px 12px 12px 14px; border-bottom: 1px solid var(--line); position: relative; }
  header::before { content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: var(--accent); }
  h2 { flex: 1; min-width: 0; font-size: 16px; font-weight: 700; line-height: 1.3; overflow-wrap: anywhere; }
  .hbtn { flex: none; width: 28px; height: 28px; display: inline-flex; align-items: center; justify-content: center; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); }
  .hbtn:hover { background: var(--panel-2); color: var(--text); border-color: var(--line-3); }

  .list { max-height: min(62vh, 560px); padding: 6px; display: flex; flex-direction: column; gap: 4px; }
  .opt {
    position: relative; display: flex; align-items: center; gap: 11px; width: 100%; text-align: left;
    padding: 9px 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--text);
    transition: background 0.1s, border-color 0.1s;
  }
  .opt.hot { background: var(--panel-2); border-color: var(--line-3); }
  .opt.hot::before { content: ''; position: absolute; left: -1px; top: 8px; bottom: 8px; width: 3px; border-radius: 2px; background: var(--accent); }
  .opt.ro { cursor: default; }
  .opt.disabled { opacity: 0.45; cursor: not-allowed; }
  .ico { flex: none; width: 30px; height: 30px; display: inline-flex; align-items: center; justify-content: center; border-radius: 6px; background: var(--panel); border: 1px solid var(--line-2); color: var(--text-2); }
  .opt.hot .ico { border-color: var(--accent-line); background: var(--accent-soft); color: var(--accent-2); }
  .body { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
  .title { font-size: 15px; font-weight: 600; line-height: 1.3; overflow-wrap: anywhere; }
  .desc { font-size: 13px; color: var(--muted); line-height: 1.35; overflow-wrap: anywhere; }
  .chev { flex: none; color: var(--faint); }
  .opt.hot .chev { color: var(--accent); }
  .prog { display: block; height: 4px; margin-top: 5px; border-radius: 4px; background: var(--panel-3); overflow: hidden; }
  .prog span { display: block; height: 100%; border-radius: 4px; }

  .tip { position: absolute; right: calc(100% + 10px); width: 240px; padding: 10px 12px; display: flex; flex-direction: column; gap: 6px; pointer-events: none; animation: fade 0.12s; }
  .ctx.left .tip { right: auto; left: calc(100% + 10px); }
  .tip img { width: 100%; max-height: 140px; object-fit: contain; border-radius: var(--radius); background: var(--bg-2); }
  .mrow { display: flex; gap: 10px; justify-content: space-between; font-size: 13px; }
  .ml { color: var(--muted); }
  .mv { color: var(--text); font-weight: 600; text-align: right; overflow-wrap: anywhere; }

  @keyframes slide { from { opacity: 0; translate: 12px 0; } to { opacity: 1; translate: 0 0; } }
  @keyframes fade { from { opacity: 0; } to { opacity: 1; } }
</style>
