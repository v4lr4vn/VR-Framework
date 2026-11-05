<script>
  import { em, itemById, flagList, FLAG_INFO, isFav, slotOf, toast } from '../lib/state.svelte.js';
  import { post } from '../lib/nui.js';

  let { onplay } = $props();

  const item = $derived(em.selected ? itemById(em.selected) : null);
  const fav = $derived(item ? isFav(item.id) : false);
  const slot = $derived(item ? slotOf(item.id) : 0);
  const shared = $derived(item && item.f.includes('W'));
  const flags = $derived(item ? flagList(item.f) : []);

  const toggleFav = async () => {
    const res = await post('fav', { id: item.id, on: !fav });
    if (res && res.state) em.state = res.state;
  };

  const assign = async (n) => {
    em.picker = false;
    const res = await post('slot', { slot: n, id: item.id });
    if (res && res.state) em.state = res.state;
    if (!em.state.keys[n - 1]) {
      em.capture = { slot: n, label: item.l, current: null };
    } else {
      toast(`${item.l} is on quick slot ${n} (${em.state.keys[n - 1]})`, 'ok');
    }
  };

  const unassign = async () => {
    em.picker = false;
    const res = await post('slot', { slot, id: null });
    if (res && res.state) em.state = res.state;
  };
</script>

{#if item}
  <div class="detail">
    <div class="info">
      <div class="name">{item.l}</div>
      <div class="meta">
        <span class="mono cmd">/e {item.k}</span>
        {#each flags as f (f)}
          <span class="chip" class:adult={f === 'A'} class:partner={f === 'W'}><i class="fa-solid fa-{FLAG_INFO[f].icon}"></i>{f === 'W' && item.t ? `With ${item.t}` : FLAG_INFO[f].label}</span>
        {/each}
      </div>
    </div>
    <div class="acts">
      {#if item.v && item.v.length}
        <select class="var" bind:value={em.variation} aria-label="Prop colour">
          {#each item.v as v, i (i)}<option value={i}>{v}</option>{/each}
        </select>
      {/if}
      <button class="icon" class:on={fav} onclick={toggleFav} title={fav ? 'Remove from favourites' : 'Add to favourites'} aria-label="Favourite">
        <i class="fa-{fav ? 'solid' : 'regular'} fa-star"></i>
      </button>
      <div class="pick">
        <button class="ghost" onclick={() => (em.picker = !em.picker)} title="Put this emote on a quick slot">
          <i class="fa-solid fa-bolt"></i>{slot ? `Slot ${slot}` : 'Quick slot'}<i class="fa-solid fa-angle-up caret"></i>
        </button>
        {#if em.picker}
          <div class="pop card" role="menu">
            <div class="pophead mono">PUT ON QUICK SLOT</div>
            {#each Array.from({ length: em.slots }, (_, i) => i + 1) as n (n)}
              {@const cur = em.state.slots[n - 1] ? itemById(em.state.slots[n - 1]) : null}
              <button class="slotrow" class:mine={slot === n} onclick={() => assign(n)}>
                <span class="n mono">{n}</span>
                <span class="who">{cur ? cur.l : 'Empty'}</span>
                {#if em.state.keys[n - 1]}<kbd class="mono">{em.state.keys[n - 1]}</kbd>{:else}<span class="nokey mono">no key</span>{/if}
              </button>
            {/each}
            {#if slot}<button class="slotrow remove" onclick={unassign}><i class="fa-solid fa-xmark"></i>Take off slot {slot}</button>{/if}
          </div>
        {/if}
      </div>
      <button class="primary" onclick={() => onplay(item)}>
        {#if shared}<i class="fa-solid fa-user-group"></i>Ask nearest player{:else}<i class="fa-solid fa-play"></i>Play{/if}
      </button>
    </div>
  </div>
{/if}

<style>
  .detail { display: flex; align-items: center; gap: 14px; padding: 12px 14px; border-top: 1px solid var(--line-2); background: rgba(0, 0, 0, 0.2); }
  .info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 6px; }
  .name { font-size: 18px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .meta { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
  .cmd { font-size: 12px; color: var(--accent-2); margin-right: 2px; }
  .chip { display: inline-flex; align-items: center; gap: 5px; height: 22px; padding: 0 8px; border-radius: 11px; background: var(--panel-2); border: 1px solid var(--line-2); color: var(--muted); font-size: 11px; }
  .chip i { font-size: 10px; }
  .chip.adult { background: var(--danger-bg); border-color: var(--danger-line); color: var(--danger-text); }
  .chip.partner { background: var(--info-bg); border-color: var(--info-line); color: var(--info-text); }
  .acts { display: flex; align-items: center; gap: 8px; }
  button { height: 38px; padding: 0 14px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel-2); color: var(--text-2); font-weight: 600; display: inline-flex; align-items: center; gap: 8px; }
  button:hover { background: var(--panel-3); color: var(--text); }
  .icon { width: 38px; padding: 0; justify-content: center; }
  .icon.on { color: var(--accent); border-color: var(--accent-line); background: var(--accent-soft); }
  .ghost { background: transparent; }
  .caret { font-size: 10px; color: var(--faint); }
  .primary { min-width: 120px; justify-content: center; background: var(--accent); border-color: var(--accent); color: var(--accent-ink); }
  .primary:hover { background: var(--accent-2); color: var(--accent-ink); }
  .var { height: 38px; max-width: 130px; padding: 0 8px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--bg-2); color: var(--text); }
  .pick { position: relative; }
  .pop { position: absolute; bottom: 46px; right: 0; width: 280px; padding: 6px; background: var(--card-solid); display: flex; flex-direction: column; gap: 2px; z-index: 30; border-color: var(--line-3); }
  .pophead { font-size: 10px; letter-spacing: 0.14em; color: var(--p2-text); padding: 4px 8px 6px; }
  .slotrow { height: 34px; padding: 0 8px; border: 1px solid transparent; background: transparent; font-weight: 500; font-size: 13px; }
  .slotrow:hover { background: var(--panel-2); border-color: var(--line-3); }
  .slotrow.mine { border-color: var(--accent-line); background: var(--accent-soft); }
  .slotrow .n { width: 20px; color: var(--info-text); font-weight: 600; }
  .slotrow .who { flex: 1; text-align: left; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--text-2); }
  .slotrow kbd { height: 20px; padding: 0 6px; border-radius: 4px; border: 1px solid var(--line-3); background: var(--panel-2); color: var(--accent-2); font-size: 11px; display: inline-flex; align-items: center; }
  .nokey { font-size: 10px; color: var(--faint); }
  .remove { color: var(--danger-text); }
</style>
