<script>
  import { ui, labelOf, imageOf, durabilityOf, priceOf, formatWeight, itemData, t } from '../lib/state.svelte.js';

  let { inv = null, index = 0, item = null, hotkey = null, mini = false, ondown = null, onhover = null, onleave = null, onmenu = null, ondouble = null } = $props();

  let broken = $state(false);
  let lastSrc = '';

  const src = $derived(item ? imageOf(item) : '');
  $effect(() => {
    if (src !== lastSrc) {
      lastSrc = src;
      broken = false;
    }
  });

  const durability = $derived(item ? durabilityOf(item) : null);
  const dTone = $derived(durability === null ? '' : durability <= 15 ? 'bad' : durability <= 45 ? 'mid' : 'good');
  const isShop = $derived(inv && inv.type === 'shop');
  const isCraft = $derived(inv && inv.type === 'crafting');
  const dragging = $derived(ui.drag && ui.drag.active && ui.drag.inv === inv && ui.drag.slot === index + 1);
  const target = $derived(ui.drag && ui.drag.active && ui.drag.over && ui.drag.over.inv === inv && ui.drag.over.slot === index + 1);
  const soldOut = $derived(isShop && item && item.count !== undefined && item.count !== null && item.count < 1);
  const ammo = $derived(item && item.metadata && typeof item.metadata.ammo === 'number' && itemData(item.name).ammoName ? item.metadata.ammo : null);
</script>

<div
  class="slot"
  class:mini
  class:filled={!!item}
  class:dragging
  class:target
  class:soldout={soldOut}
  data-slot={index + 1}
  data-inv={inv === ui.player ? 'player' : 'right'}
  role="button"
  tabindex="-1"
  onpointerdown={(e) => ondown && ondown(e, inv, index + 1)}
  onpointerenter={(e) => item && onhover && onhover(e, inv, index + 1)}
  onpointerleave={() => onleave && onleave()}
  oncontextmenu={(e) => { e.preventDefault(); if (item && onmenu) onmenu(e, inv, index + 1); }}
  ondblclick={() => item && ondouble && ondouble(inv, index + 1)}
>
  {#if hotkey}<span class="key">{hotkey}</span>{/if}
  {#if item}
    <div class="top">
      {#if isShop}
        {#if item.count !== undefined && item.count !== null}<span class="stock mono">{item.count}</span>{/if}
        <span class="tag mono" class:out={soldOut}>
          {#if soldOut}{t('ui_out_of_stock')}{:else if !item.currency || item.currency === 'money'}{priceOf(item)}{:else}{item.price}<img class="cur" src={imageOf({ name: item.currency })} alt="" />{/if}
        </span>
      {:else if isCraft}
        {#if item.count && item.count > 1}<span class="count mono">×{item.count}</span>{/if}
      {:else}
        {#if item.count > 1}<span class="count mono">×{item.count}</span>
        {:else if ammo !== null}<span class="count mono ammo"><i class="fa-solid fa-circle-dot"></i>{ammo}</span>{/if}
      {/if}
      {#if !mini && !isShop && !isCraft && item.weight}<span class="weight mono">{formatWeight(item.weight)}</span>{/if}
    </div>
    <div class="art">
      {#if src && !broken}
        <img src={src} alt="" draggable="false" onerror={() => (broken = true)} />
      {:else}
        <i class="fa-solid fa-box fallback"></i>
      {/if}
    </div>
    <div class="foot">
      <span class="label">{labelOf(item)}</span>
    </div>
    {#if durability !== null}
      <span class="dura {dTone}"><span style:width="{durability}%"></span></span>
    {/if}
  {/if}
</div>

<style>
  .slot {
    position: relative; width: var(--slot); height: var(--slot); border-radius: var(--radius);
    background: linear-gradient(180deg, rgba(26, 36, 51, 0.55), rgba(17, 24, 35, 0.75));
    border: 1px solid var(--line-2); overflow: hidden; user-select: none; outline: none;
    transition: border-color 0.12s, background 0.12s, opacity 0.12s;
  }
  .slot.filled { cursor: grab; }
  .slot:hover { border-color: var(--line-3); background: linear-gradient(180deg, rgba(36, 50, 74, 0.6), rgba(26, 36, 51, 0.8)); }
  .slot.filled:hover { border-color: var(--accent-line); }
  .slot.dragging { opacity: 0.35; }
  .slot.target { border-color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent), 0 0 0 3px var(--accent-soft); }
  .slot.soldout .art { opacity: 0.35; filter: grayscale(1); }

  .key {
    position: absolute; left: 0; top: 0; z-index: 2; min-width: 18px; height: 18px; padding: 0 5px;
    border-bottom-right-radius: 5px; background: var(--accent); color: var(--accent-ink);
    font-family: var(--mono); font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; justify-content: center;
  }
  .top { position: absolute; left: 6px; right: 6px; top: 4px; display: flex; justify-content: space-between; align-items: center; gap: 4px; z-index: 1; pointer-events: none; }
  .key + .top { left: 24px; }
  .count { font-size: 12px; color: var(--text); font-weight: 600; text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8); }
  .count.ammo { color: var(--accent-2); display: inline-flex; align-items: center; gap: 3px; }
  .count.ammo i { font-size: 8px; }
  .stock { font-size: 11px; color: var(--muted); font-weight: 600; }
  .tag { margin-left: auto; display: inline-flex; align-items: center; gap: 3px; height: 18px; padding: 0 6px; border-radius: 4px; background: var(--ok-bg); border: 1px solid var(--ok-line); color: var(--ok); font-size: 11px; font-weight: 700; }
  .tag.out { background: var(--danger-bg); border-color: var(--danger-line); color: var(--danger-text); }
  .cur { width: 13px; height: 13px; object-fit: contain; }
  .weight { margin-left: auto; font-size: 10px; color: var(--faint); }
  .art { position: absolute; inset: 18% 14% 26% 14%; display: flex; align-items: center; justify-content: center; pointer-events: none; }
  .art img { max-width: 100%; max-height: 100%; object-fit: contain; filter: drop-shadow(0 4px 6px rgba(0, 0, 0, 0.55)); }
  .fallback { font-size: calc(var(--slot) * 0.28); color: var(--line-3); }
  .foot { position: absolute; left: 0; right: 0; bottom: 0; height: 22%; display: flex; align-items: center; justify-content: center; padding: 0 6px; background: linear-gradient(0deg, rgba(10, 14, 20, 0.92), rgba(10, 14, 20, 0.35)); border-top: 1px solid rgba(43, 58, 80, 0.55); pointer-events: none; }
  .label { font-size: 12px; font-weight: 600; color: var(--text-2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%; }
  .dura { position: absolute; left: 0; right: 0; bottom: 0; height: 3px; background: rgba(10, 14, 20, 0.9); pointer-events: none; }
  .dura span { display: block; height: 100%; }
  .dura.good span { background: var(--ok); }
  .dura.mid span { background: var(--warn); }
  .dura.bad span { background: var(--danger); }

  @media (max-height: 820px) { .weight { display: none; } .label { font-size: 11px; } }
  .slot.mini .foot { display: none; }
  .slot.mini .art { inset: 18% 14% 12% 14%; }
</style>
