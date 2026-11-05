<script>
  import Card from '../ui/Card.svelte';
  import Slab from '../ui/Slab.svelte';
  import { money, pad } from '../lib/api.js';

  let { c, meta, onclose, actions } = $props();

  let rar = $derived(meta?.rarities?.[c.rarity] || {});
  let grp = $derived(meta?.groups?.[c.group] || {});
  function key(e) {
    if (e.key !== 'Escape') return;
    e.stopPropagation();
    onclose?.();
  }

  const SUB = [['centering', 'Centering'], ['corners', 'Corners'], ['edges', 'Edges'], ['surface', 'Surface']];
</script>

<svelte:window onkeydown={key} />

<div class="viewer" role="dialog" aria-modal="true" aria-label={c.name}>
  <div class="scrim" role="presentation" onclick={onclose}></div>
  <div class="wrap">
    <div class="show">
      {#if c.grade}
        <Slab {c} {meta} w={260} />
      {:else}
        <Card {c} {meta} w={320} live />
      {/if}
    </div>
    <aside class="info card">
      <div class="top">
        <div>
          <span class="label">{c.setLabel} · {c.set} {pad(c.number)}/{pad(c.total)}</span>
          <h2>{c.name}</h2>
          <p class="sub">{c.title}</p>
        </div>
        <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
      </div>
      <div class="chips">
        <span class="chip" style="color:{rar.color}; border-color:{rar.color}"><i class="fa-solid fa-diamond"></i>{rar.label}</span>
        {#if c.foil && c.foil !== 'none'}<span class="chip accent"><i class="fa-solid fa-wand-magic-sparkles"></i>{meta?.foils?.[c.foil]}</span>{/if}
        <span class="chip"><i class="fa-solid fa-{grp.icon}"></i>{grp.label}</span>
      </div>
      <p class="quote">“{c.quote}”</p>
      <div class="rows">
        {#if c.serial}<div class="r"><span>Print number</span><span class="num">#{c.serial}</span></div>{/if}
        {#if c.price != null}<div class="r"><span>Shop buys it for</span><span class="num">{money(c.price)}</span></div>{/if}
      </div>
      {#if c.grade}
        <div class="graded">
          <div class="gh">
            <span class="g num">{c.grade}</span>
            <div><b>{meta?.grades?.[c.grade]}</b><span class="hint">{meta?.companyName} · cert <span class="num">{c.cert}</span></span></div>
          </div>
          {#if c.sub}
            {#each SUB as [k, label]}
              <div class="sg">
                <span>{label}</span>
                <div class="bar" class:ok={c.sub[k] >= 9}><span style="width:{c.sub[k] * 10}%"></span></div>
                <span class="num">{c.sub[k]}</span>
              </div>
            {/each}
          {/if}
        </div>
      {:else}
        <p class="hint">Ungraded. Send it to {meta?.companyName || 'the grader'} at the card shop to find out its grade.</p>
      {/if}
      {#if actions}<div class="act">{@render actions()}</div>{/if}
    </aside>
  </div>
</div>

<style>
  .viewer { position: fixed; inset: 0; z-index: 30; display: grid; place-items: center; }
  .scrim { position: absolute; inset: 0; background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.75), rgba(6, 9, 13, 0.94)); }
  .wrap { position: relative; display: flex; align-items: center; gap: 40px; padding: 20px; max-width: calc(100vw - 32px); }
  .show { display: grid; place-items: center; animation: rise 0.4s var(--ease); }
  @keyframes rise { from { transform: translateY(20px) scale(0.96); opacity: 0; } }
  .info { width: 360px; padding: 18px; display: flex; flex-direction: column; gap: 14px; }
  .top { display: flex; align-items: flex-start; justify-content: space-between; gap: 10px; }
  h2 { font-size: 24px; font-weight: 700; margin-top: 4px; }
  .sub { color: var(--muted); font-size: 13px; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); flex: none; }
  .x:hover { color: var(--text); background: var(--panel-2); }
  .chips { display: flex; gap: 6px; flex-wrap: wrap; }
  .chips .chip { height: 24px; font-size: 11px; }
  .quote { color: var(--text-2); font-style: italic; font-size: 13px; line-height: 1.45; }
  .rows { display: flex; flex-direction: column; gap: 6px; }
  .r { display: flex; justify-content: space-between; font-size: 13px; color: var(--text-2); padding: 6px 0; border-bottom: 1px solid var(--line); }
  .graded { display: flex; flex-direction: column; gap: 8px; padding: 12px; border-radius: var(--radius-lg); background: var(--bg-2); border: 1px solid var(--line-2); }
  .gh { display: flex; align-items: center; gap: 12px; margin-bottom: 4px; }
  .gh .g { font-size: 38px; font-weight: 600; color: var(--accent-2); line-height: 1; }
  .gh b { display: block; font-size: 15px; }
  .sg { display: grid; grid-template-columns: 80px 1fr 24px; align-items: center; gap: 10px; font-size: 12px; color: var(--text-2); }
  .sg .num { text-align: right; }
  .act { display: flex; gap: 8px; flex-wrap: wrap; }
</style>
