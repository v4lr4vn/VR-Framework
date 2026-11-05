<script>
  import Icon from '../../components/Icon.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Badge from '../../components/Badge.svelte';
  import { penal, chargeById } from './penal.svelte.js';
  import { classShort, classTone, classLabel, totals } from './util.js';
  import { money } from '../../lib/format.js';

  let { value = $bindable([]), known = [], maxCount = 10, id } = $props();

  let q = $state('');
  let open = $state(false);
  let active = $state(0);
  let root;
  const listId = `cpl-${Math.random().toString(36).slice(2, 9)}`;

  function lookup(cid) {
    penal.version;
    return chargeById(cid) || known.find((k) => k.id === cid) || null;
  }

  const rows = $derived(value.map((e) => ({ ...e, charge: lookup(e.id) })));
  const sum = $derived(totals(value, lookup));

  const matches = $derived.by(() => {
    const term = q.trim().toLowerCase();
    const out = [];
    for (const cat of penal.categories) {
      const list = cat.charges.filter((c) => c.active !== false && (!term || c.title.toLowerCase().includes(term) || cat.name.toLowerCase().includes(term)));
      if (list.length) out.push({ cat, list });
    }
    return out;
  });
  const flat = $derived(matches.flatMap((g) => g.list));

  function add(c) {
    const at = value.findIndex((e) => e.id === c.id);
    if (at >= 0) value = value.map((e, i) => (i === at ? { ...e, count: Math.min(e.count + 1, maxCount) } : e));
    else value = [...value, { id: c.id, count: 1 }];
    q = '';
    active = 0;
    open = false;
  }

  function setCount(i, n) {
    value = value.map((e, j) => (j === i ? { ...e, count: Math.max(1, Math.min(maxCount, n)) } : e));
  }

  function remove(i) {
    value = value.filter((_, j) => j !== i);
  }

  function key(e) {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      open = true;
      active = Math.min(active + 1, Math.max(flat.length - 1, 0));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      active = Math.max(active - 1, 0);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (flat[active]) add(flat[active]);
    } else if (e.key === 'Escape' && open) {
      e.stopPropagation();
      open = false;
    }
  }

  function outside(e) {
    if (open && root && !root.contains(e.target)) open = false;
  }
</script>

<svelte:window onmousedown={outside} />

<div class="cp" bind:this={root}>
  {#if rows.length}
    <div class="rows">
      {#each rows as r, i (r.id)}
        <div class="row" class:inactive={r.charge && r.charge.active === false}>
          <span class="cls"><Badge tone={classTone(r.charge?.class)} mono>{classShort(r.charge?.class) || '?'}</Badge></span>
          <span class="title">{r.charge?.title || `Charge #${r.id}`}{#if r.charge && r.charge.active === false}<span class="retired">Retired</span>{/if}</span>
          <span class="num mono">{money((r.charge?.fine || 0) * r.count)}</span>
          <span class="num mono mo">{r.charge?.months ? `${r.charge.months * r.count} mo` : '—'}</span>
          <div class="stepper" role="group" aria-label="Count for {r.charge?.title || 'charge'}">
            <button type="button" class="st" aria-label="One fewer" disabled={r.count <= 1} onclick={() => setCount(i, r.count - 1)}><Icon name="minus" size={12} /></button>
            <span class="n mono" aria-live="polite">{r.count}</span>
            <button type="button" class="st" aria-label="One more" disabled={r.count >= maxCount} onclick={() => setCount(i, r.count + 1)}><Icon name="plus" size={12} /></button>
          </div>
          <IconButton icon="x" label="Remove {r.charge?.title || 'charge'}" size={26} variant="danger" onclick={() => remove(i)} />
        </div>
      {/each}
    </div>
  {/if}

  <div class="add">
    <label class="box">
      <Icon name="scale" size={15} />
      <span class="sr-only">Add a charge</span>
      <input {id} bind:value={q} placeholder={penal.loaded ? 'Add a charge' : 'Loading the penal code…'} disabled={!penal.loaded} oninput={() => { open = true; active = 0; }} onfocus={() => (open = true)} onkeydown={key} spellcheck="false" autocomplete="off" role="combobox" aria-expanded={open} aria-controls={listId} />
    </label>
    {#if open && penal.loaded}
      <div class="drop scroll" role="listbox" id={listId}>
        {#each matches as g (g.cat.id)}
          <span class="eyebrow grp">{g.cat.name}</span>
          {#each g.list as c (c.id)}
            {@const idx = flat.indexOf(c)}
            <button type="button" role="option" class="opt" class:on={idx === active} aria-selected={idx === active} onmouseenter={() => (active = idx)} onclick={() => add(c)}>
              <Badge tone={classTone(c.class)} mono>{classShort(c.class)}</Badge>
              <span class="ot">{c.title}</span>
              <span class="om mono">{money(c.fine)}</span>
              <span class="om mono mo">{c.months ? `${c.months} mo` : '—'}</span>
            </button>
          {/each}
        {:else}
          <p class="none">No charge matches "{q}".</p>
        {/each}
      </div>
    {/if}
  </div>

  <div class="sum" class:empty={!rows.length}>
    {#if rows.length}
      <span><b class="mono">{money(sum.fine)}</b> fine</span>
      <span><b class="mono">{sum.months}</b> {sum.months === 1 ? 'month' : 'months'}</span>
      <span><b class="mono">{sum.points}</b> {sum.points === 1 ? 'point' : 'points'}</span>
      {#if sum.class}<Badge tone={classTone(sum.class)}>{classLabel(sum.class)}</Badge>{/if}
    {:else}
      <span class="hint">No charges yet. Search above to add them.</span>
    {/if}
  </div>
</div>

<style>
  .cp { display: flex; flex-direction: column; gap: 8px; }
  .rows { display: flex; flex-direction: column; border: 1px solid var(--line); border-radius: var(--radius); overflow: hidden; }
  .row { display: flex; align-items: center; gap: 10px; padding: 6px 8px 6px 10px; background: var(--bg-2); }
  .row + .row { border-top: 1px solid var(--line); }
  .inactive .title { color: var(--muted); }
  .cls { width: 44px; flex: none; }
  .title { flex: 1; min-width: 0; color: var(--text); font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .retired { margin-left: 8px; font-size: 11px; font-weight: 600; color: var(--muted); text-transform: uppercase; letter-spacing: 0.08em; }
  .num { width: 76px; text-align: right; color: var(--text-2); font-size: 13px; flex: none; }
  .mo { width: 56px; }
  .stepper { display: flex; align-items: center; border: 1px solid var(--line-2); border-radius: var(--radius); height: 26px; flex: none; }
  .st { width: 24px; height: 24px; border: 0; background: transparent; color: var(--text-2); display: flex; align-items: center; justify-content: center; padding: 0; }
  .st:hover:not(:disabled) { color: var(--accent); }
  .n { width: 22px; text-align: center; font-size: 13px; }
  .add { position: relative; }
  .box { display: flex; align-items: center; gap: 10px; height: 34px; padding: 0 12px; border-radius: var(--radius); border: 1px dashed var(--line-3); background: transparent; color: var(--muted); }
  .box:focus-within { border-style: solid; border-color: var(--accent); background: var(--bg-2); }
  input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); }
  input::placeholder { color: var(--faint); }
  .drop { position: absolute; left: 0; right: 0; top: 38px; max-height: 300px; padding: 4px; border-radius: var(--radius-lg); border: 1px solid var(--line-3); background: var(--bg-2); box-shadow: var(--shadow); z-index: 40; display: flex; flex-direction: column; gap: 1px; }
  .grp { padding: 8px 10px 4px; }
  .opt { display: flex; align-items: center; gap: 10px; min-height: 32px; padding: 0 10px; border: 0; border-radius: var(--radius); background: transparent; color: var(--text-2); text-align: left; flex: none; }
  .opt.on { background: var(--panel-2); }
  .ot { flex: 1; min-width: 0; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .om { width: 70px; text-align: right; color: var(--muted); font-size: 12px; flex: none; }
  .none { padding: 10px; color: var(--muted); font-size: 13px; }
  .sum { display: flex; align-items: center; gap: 16px; padding: 8px 12px; border-radius: var(--radius); background: var(--panel-2); color: var(--muted); font-size: 13px; }
  .sum b { color: var(--text); font-weight: 600; font-size: 14px; }
  .sum.empty { background: transparent; padding: 0 2px; }
  .hint { color: var(--faint); }
</style>
