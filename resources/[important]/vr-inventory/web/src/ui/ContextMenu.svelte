<script>
  import { post } from '../lib/nui.js';
  import { ui, t, itemData, labelOf } from '../lib/state.svelte.js';
  import { useSlot, giveSlot, splitStack, dropToGround, quickMove, copyText, amountFor } from '../lib/actions.js';

  let el = $state(null);
  let pos = $state({ x: 0, y: 0 });
  let splitting = $state(false);
  let splitValue = $state(1);
  let input = $state(null);

  const menu = $derived(ui.menu);
  const inv = $derived(menu && menu.inv);
  const item = $derived(menu && inv ? inv.items[menu.slot - 1] : null);
  const isPlayer = $derived(inv === ui.player);
  const data = $derived(item ? itemData(item.name) : {});
  const meta = $derived(item && item.metadata && !Array.isArray(item.metadata) ? item.metadata : {});
  const ground = $derived(ui.right && (ui.right.type === 'newdrop' || ui.right.type === 'drop'));
  const other = $derived(ui.right && !['shop', 'crafting', 'inspect'].includes(ui.right.type));
  const components = $derived(Array.isArray(meta.components) ? meta.components : []);

  const groups = $derived.by(() => {
    const list = Array.isArray(data.buttons) ? data.buttons : [];
    const out = [];
    const byGroup = new Map();
    list.forEach((b, i) => {
      if (!b) return;
      const entry = { label: b.label, id: i + 1 };
      if (b.group) {
        if (!byGroup.has(b.group)) {
          const g = { group: b.group, items: [] };
          byGroup.set(b.group, g);
          out.push(g);
        }
        byGroup.get(b.group).items.push(entry);
      } else {
        out.push(entry);
      }
    });
    return out;
  });

  let openGroup = $state(null);

  $effect(() => {
    if (!menu) {
      splitting = false;
      openGroup = null;
      return;
    }
    if (!el) return;
    const w = el.offsetWidth;
    const h = el.offsetHeight;
    let x = menu.x + 4;
    let y = menu.y + 4;
    if (x + w > window.innerWidth - 8) x = menu.x - w - 4;
    if (y + h > window.innerHeight - 8) y = Math.max(8, window.innerHeight - h - 8);
    pos = { x, y };
  });

  $effect(() => {
    if (splitting && input) {
      input.focus();
      input.select();
    }
  });

  const done = () => (ui.menu = null);
  const run = (fn) => {
    const slot = menu.slot;
    const target = inv;
    const current = item;
    done();
    fn(slot, target, current);
  };

  const startSplit = () => {
    splitValue = Math.max(1, Math.floor(item.count / 2));
    splitting = true;
  };

  const confirmSplit = () => {
    const n = Math.floor(Number(splitValue) || 0);
    run((slot, target) => splitStack(target, slot, n));
  };
</script>

{#if item}
  <div class="menu" bind:this={el} style:left="{pos.x}px" style:top="{pos.y}px" role="menu">
    <div class="head"><span>{labelOf(item)}</span>{#if item.count > 1}<em class="mono">×{item.count}</em>{/if}</div>

    {#if splitting}
      <div class="split">
        <input bind:this={input} class="mono" type="number" min="1" max={item.count - 1} bind:value={splitValue}
          onkeydown={(e) => { if (e.key === 'Enter') confirmSplit(); if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); splitting = false; } }} />
        <input class="range" type="range" min="1" max={item.count - 1} bind:value={splitValue} />
        <button class="go" onclick={confirmSplit} aria-label={t('ui_split')}><i class="fa-solid fa-check"></i></button>
      </div>
    {:else}
      {#if isPlayer}
        <button onclick={() => run((slot) => useSlot(slot))}><i class="fa-solid fa-hand-pointer"></i>{t('ui_use')}</button>
        <button onclick={() => run((slot, _, current) => giveSlot(slot, amountFor(current)))}><i class="fa-solid fa-hand-holding"></i>{t('ui_give')}</button>
        {#if item.count > 1}<button onclick={startSplit}><i class="fa-solid fa-scissors"></i>{t('ui_split')}</button>{/if}
        {#if ground}<button onclick={() => run((slot, _, current) => dropToGround(slot, amountFor(current)))}><i class="fa-solid fa-arrow-down"></i>{t('ui_drop')}</button>{/if}
        {#if typeof meta.ammo === 'number' && meta.ammo > 0 && data.ammoName}
          <button onclick={() => run((slot) => post('removeAmmo', slot))}><i class="fa-solid fa-box-open"></i>{t('ui_remove_ammo')}</button>
        {/if}
        {#if components.length}
          <div class="sep"></div>
          <div class="sect">{t('ui_removeattachments')}</div>
          {#each components as c (c)}
            <button onclick={() => run((slot) => post('removeComponent', { slot, component: c }))}><i class="fa-solid fa-wrench"></i>{itemData(c).label || c}</button>
          {/each}
        {/if}
        {#if meta.serial}
          <button onclick={() => run(() => copyText(meta.serial))}><i class="fa-solid fa-copy"></i>{t('ui_copy')}</button>
        {/if}
        {#if groups.length}
          <div class="sep"></div>
          {#each groups as g, gi (gi)}
            {#if g.group}
              <button class="grp" onclick={() => (openGroup = openGroup === g.group ? null : g.group)}><i class="fa-solid fa-angle-right" class:open={openGroup === g.group}></i>{g.group}</button>
              {#if openGroup === g.group}
                {#each g.items as b (b.id)}
                  <button class="sub" onclick={() => run((slot) => post('useButton', { id: b.id, slot }))}>{b.label}</button>
                {/each}
              {/if}
            {:else}
              <button onclick={() => run((slot) => post('useButton', { id: g.id, slot }))}><i class="fa-solid fa-circle-dot"></i>{g.label}</button>
            {/if}
          {/each}
        {/if}
      {:else if other}
        <button onclick={() => run((slot, target) => quickMove(target, slot, false))}><i class="fa-solid fa-arrow-left"></i>{t('ui_amount_all')}</button>
        {#if item.count > 1}<button onclick={() => run((slot, target) => quickMove(target, slot, true))}><i class="fa-solid fa-arrow-left"></i>½</button>{/if}
        {#if item.count > 1}<button onclick={startSplit}><i class="fa-solid fa-scissors"></i>{t('ui_split')}</button>{/if}
      {/if}
    {/if}
  </div>
{/if}

<style>
  .menu {
    position: fixed; z-index: 70; min-width: 196px; max-width: 260px; padding: 6px;
    background: var(--card-solid); border: 1px solid var(--line-3); border-radius: var(--radius-lg);
    box-shadow: 0 16px 36px rgba(0, 0, 0, 0.6); display: flex; flex-direction: column; gap: 2px;
    animation: pop 0.1s ease-out;
  }
  @keyframes pop { from { opacity: 0; transform: scale(0.97); } to { opacity: 1; transform: none; } }
  .head { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; padding: 6px 8px 8px; border-bottom: 1px solid var(--line); margin-bottom: 4px; font-weight: 700; font-size: 14px; }
  .head span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .head em { font-style: normal; color: var(--faint); font-size: 12px; }
  button { display: flex; align-items: center; gap: 10px; height: 32px; padding: 0 10px; border: 0; border-radius: var(--radius); background: transparent; color: var(--text-2); text-align: left; font-size: 14px; font-weight: 500; }
  button i { width: 14px; text-align: center; color: var(--muted); font-size: 12px; transition: transform 0.12s; }
  button i.open { transform: rotate(90deg); }
  button:hover { background: var(--panel-2); color: var(--text); }
  button:hover i { color: var(--accent-2); }
  .sub { padding-left: 34px; height: 30px; font-size: 13px; }
  .sep { height: 1px; background: var(--line); margin: 4px 2px; }
  .sect { padding: 2px 10px; font-family: var(--mono); font-size: 10px; letter-spacing: 0.12em; text-transform: uppercase; color: var(--p2-text); font-weight: 600; }
  .split { display: flex; align-items: center; gap: 6px; padding: 4px; }
  .split input[type='number'] { width: 64px; height: 32px; padding: 0 8px; border-radius: var(--radius); border: 1px solid var(--accent-line); background: var(--bg); color: var(--text); outline: none; font-size: 14px; }
  .range { flex: 1; min-width: 0; accent-color: var(--accent); }
  .go { width: 32px; justify-content: center; padding: 0; background: var(--accent); color: var(--accent-ink); }
  .go i { color: var(--accent-ink); }
  .go:hover { background: var(--accent-2); }
  .go:hover i { color: var(--accent-ink); }
</style>
