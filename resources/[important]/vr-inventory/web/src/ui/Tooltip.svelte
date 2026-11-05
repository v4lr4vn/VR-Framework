<script>
  import { md } from '../lib/md.js';
  import { ui, t, itemData, labelOf, descriptionOf, durabilityOf, formatWeight, priceOf, counts } from '../lib/state.svelte.js';

  let el = $state(null);
  let pos = $state({ x: 0, y: 0 });

  const tip = $derived(ui.tooltip);
  const inv = $derived(tip && tip.inv);
  const item = $derived(tip && inv ? inv.items[tip.slot - 1] : null);
  const data = $derived(item ? itemData(item.name) : {});
  const meta = $derived((item && item.metadata && !Array.isArray(item.metadata) ? item.metadata : {}) || {});
  const durability = $derived(item ? durabilityOf(item) : null);
  const isShop = $derived(inv && inv.type === 'shop');
  const isCraft = $derived(inv && inv.type === 'crafting');
  const have = $derived(isCraft ? counts() : {});
  const components = $derived(Array.isArray(meta.components) ? meta.components : []);
  const extras = $derived.by(() => {
    const out = [];
    for (const [key, label] of Object.entries(ui.meta)) {
      const v = meta[key];
      if (v !== undefined && v !== null && v !== '' && typeof v !== 'object') out.push({ label, value: String(v) });
    }
    return out;
  });
  const ingredients = $derived.by(() => {
    if (!isCraft || !item || !item.ingredients) return [];
    return Object.entries(item.ingredients).map(([name, need]) => {
      const tool = need < 1;
      const got = have[name] || 0;
      return { name, label: itemData(name).label || name, need, tool, ok: tool ? got > 0 : got >= need, got };
    });
  });

  $effect(() => {
    if (!tip || !el) return;
    const w = el.offsetWidth;
    const h = el.offsetHeight;
    let x = tip.x + 18;
    let y = tip.y + 14;
    if (x + w > window.innerWidth - 8) x = tip.x - w - 14;
    if (y + h > window.innerHeight - 8) y = Math.max(8, window.innerHeight - h - 8);
    pos = { x, y };
  });
</script>

{#if item && !ui.drag?.active && !ui.menu}
  <div class="tip" bind:this={el} style:left="{pos.x}px" style:top="{pos.y}px">
    <div class="head">
      <span class="name">{labelOf(item)}</span>
      <span class="id mono">{item.name}</span>
    </div>

    {#if descriptionOf(item)}<div class="desc md">{@html md(descriptionOf(item))}</div>{/if}

    <div class="rows">
      {#if isShop}
        <div class="r"><span>{t('ui_price')}</span><b class="mono ok">{priceOf(item)}</b></div>
        {#if item.count !== undefined && item.count !== null}<div class="r"><span>{t('ui_stock')}</span><b class="mono">{item.count}</b></div>{/if}
        {#if item.license}<div class="r warnrow"><span><i class="fa-solid fa-id-card"></i> {t('ui_license', item.license)}</span></div>{/if}
        {#if item.weight}<div class="r"><span>{t('ui_weight')}</span><b class="mono">{formatWeight(item.weight)}</b></div>{/if}
      {:else if isCraft}
        <div class="r"><span>{t('ui_makes')}</span><b class="mono">×{Array.isArray(item.count) ? item.count.join('–') : item.count || 1}</b></div>
        {#if item.duration}<div class="r"><span>{t('ui_crafting_time')}</span><b class="mono">{(item.duration / 1000).toFixed(1)}s</b></div>{/if}
        {#if ingredients.length}
          <div class="sect">{t('ui_ingredients')}</div>
          {#each ingredients as ing (ing.name)}
            <div class="r ing" class:ok={ing.ok} class:bad={!ing.ok}>
              <span><i class="fa-solid {ing.ok ? 'fa-check' : 'fa-xmark'}"></i> {ing.label}</span>
              <b class="mono">{ing.tool ? `${Math.round(ing.need * 100)}%` : `${Math.min(ing.got, ing.need)}/${ing.need}`}</b>
            </div>
          {/each}
        {/if}
      {:else}
        <div class="r"><span>{t('ui_weight')}</span><b class="mono">{formatWeight(item.weight)}</b></div>
        {#if item.count > 1}<div class="r"><span>{t('ui_count')}</span><b class="mono">{item.count}</b></div>{/if}
      {/if}

      {#if durability !== null && !isShop && !isCraft}
        <div class="r"><span>{t('ui_durability')}</span><b class="mono">{Math.floor(durability)}%</b></div>
        <span class="dbar"><span style:width="{durability}%" class:mid={durability <= 45} class:bad={durability <= 15}></span></span>
      {/if}
      {#if typeof meta.ammo === 'number' && data.ammoName}
        <div class="r"><span>{t('ui_ammo')}</span><b class="mono">{meta.ammo}{#if meta.specialAmmo} · {meta.specialAmmo}{/if}</b></div>
      {/if}
      {#if meta.serial}<div class="r"><span>{t('ui_serial')}</span><b class="mono">{meta.serial}</b></div>{/if}
      {#if meta.registered}<div class="r"><span>{t('ui_registered')}</span><b>{meta.registered}</b></div>{/if}
      {#if meta.tint !== undefined && meta.tint !== null}<div class="r"><span>{t('ui_tint')}</span><b class="mono">{meta.tint}</b></div>{/if}
      {#if components.length}
        <div class="sect">{t('ui_components')}</div>
        <div class="chips">
          {#each components as c (c)}<span class="chip">{itemData(c).label || c}</span>{/each}
        </div>
      {/if}
      {#if data.ammo && meta.type !== undefined && typeof meta.type !== 'object' && !ui.meta.type}<div class="r"><span>{t('ammo_type')}</span><b>{meta.type}</b></div>{/if}
      {#each extras as x (x.label)}<div class="r"><span>{x.label}</span><b>{x.value}</b></div>{/each}
    </div>
  </div>
{/if}

<style>
  .tip {
    position: fixed; z-index: 60; width: 264px; padding: 12px 14px; pointer-events: none;
    background: var(--card-solid); border: 1px solid var(--line-3); border-radius: var(--radius-lg);
    box-shadow: 0 14px 34px rgba(0, 0, 0, 0.6); animation: pop 0.1s ease-out;
  }
  @keyframes pop { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
  .head { display: flex; flex-direction: column; gap: 1px; padding-bottom: 8px; border-bottom: 1px solid var(--line); }
  .name { font-size: 16px; font-weight: 700; color: var(--text); }
  .id { font-size: 11px; color: var(--faint); }
  .desc { padding-top: 8px; font-size: 13px; color: var(--text-2); line-height: 1.4; }
  .rows { display: flex; flex-direction: column; gap: 5px; padding-top: 8px; }
  .r { display: flex; justify-content: space-between; align-items: baseline; gap: 10px; font-size: 13px; color: var(--muted); }
  .r b { color: var(--text); font-weight: 600; text-align: right; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 62%; }
  .r b.ok { color: var(--ok); }
  .warnrow { color: var(--warn-text); }
  .sect { margin-top: 4px; font-family: var(--mono); font-size: 10px; letter-spacing: 0.12em; text-transform: uppercase; color: var(--p2-text); font-weight: 600; }
  .ing.ok { color: var(--ok-text); }
  .ing.bad { color: var(--danger-text); }
  .ing i { width: 14px; font-size: 11px; }
  .dbar { display: block; height: 3px; border-radius: 2px; background: var(--line); overflow: hidden; }
  .dbar span { display: block; height: 100%; background: var(--ok); }
  .dbar span.mid { background: var(--warn); }
  .dbar span.bad { background: var(--danger); }
  .chips { display: flex; flex-wrap: wrap; gap: 4px; }
  .chip { font-size: 11px; padding: 2px 7px; border-radius: 10px; border: 1px solid var(--line-3); color: var(--text-2); background: var(--panel); }
</style>
