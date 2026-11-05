<script>
  import { em, flagList, FLAG_INFO, isFav, slotOf } from '../lib/state.svelte.js';

  let { item, onhover, onpick, onplay } = $props();

  const on = $derived(em.selected === item.id);
  const playing = $derived(em.state.playing === item.id);
  const fav = $derived(isFav(item.id));
  const slot = $derived(slotOf(item.id));
  const flags = $derived(flagList(item.f).filter((f) => f !== 'W'));
</script>

<button
  class="card"
  class:on
  class:playing
  onmouseenter={() => onhover && onhover(item)}
  onclick={() => onpick && onpick(item)}
  ondblclick={() => onplay && onplay(item)}
>
  <div class="top">
    <span class="label">{item.l}</span>
    {#if fav}<i class="fa-solid fa-star fav" title="Favourite"></i>{/if}
    {#if slot}<span class="slot mono" title="Quick slot {slot}">{slot}</span>{/if}
  </div>
  <div class="bottom">
    <span class="cmd mono">/e {item.k}</span>
    {#if item.t}<span class="with"><i class="fa-solid fa-user-group"></i>{item.t}</span>{/if}
    {#if item.p}<span class="pack mono">{item.p}</span>{/if}
    <span class="flags">
      {#each flags as f (f)}
        <i class="fa-solid fa-{FLAG_INFO[f].icon}" class:adult={f === 'A'} title={FLAG_INFO[f].label}></i>
      {/each}
    </span>
  </div>
  {#if playing}<span class="live mono">PLAYING</span>{/if}
</button>

<style>
  .card {
    position: relative; width: 100%; height: 100%; display: flex; flex-direction: column; justify-content: center; gap: 6px;
    padding: 0 12px; border-radius: var(--radius-lg); border: 1px solid var(--line); background: var(--panel);
    color: var(--text); text-align: left; overflow: hidden; transition: border-color 0.12s, background 0.12s;
  }
  .card:hover { border-color: var(--line-3); background: var(--panel-2); }
  .card.on { border-color: var(--accent); background: linear-gradient(90deg, var(--accent-soft), transparent 70%), var(--panel-2); }
  .card.playing { border-color: var(--ok-line); }
  .top { display: flex; align-items: center; gap: 8px; min-width: 0; }
  .label { flex: 1; min-width: 0; font-weight: 600; font-size: 15px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .fav { color: var(--accent); font-size: 12px; }
  .slot { min-width: 18px; height: 18px; padding: 0 5px; border-radius: 4px; background: var(--info-bg); border: 1px solid var(--info-line); color: var(--info-text); font-size: 11px; font-weight: 600; display: inline-flex; align-items: center; justify-content: center; }
  .bottom { display: flex; align-items: center; gap: 8px; min-width: 0; color: var(--faint); font-size: 12px; }
  .cmd { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 55%; color: var(--muted); }
  .with { display: inline-flex; align-items: center; gap: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--info-text); }
  .with i { font-size: 10px; }
  .pack { font-size: 10px; color: var(--doj-text); }
  .flags { margin-left: auto; display: inline-flex; gap: 7px; font-size: 11px; color: var(--muted); }
  .flags .adult { color: var(--danger-text); }
  .live { position: absolute; top: 0; right: 0; padding: 2px 6px; border-bottom-left-radius: 6px; background: var(--ok-bg); color: var(--ok-text); font-size: 9px; letter-spacing: 0.12em; font-weight: 600; }
</style>
