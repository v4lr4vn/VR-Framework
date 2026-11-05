<script>
  import Slot from './Slot.svelte';
  import { ui, t, typeInfo, titleOf, formatKg } from '../lib/state.svelte.js';

  let { inv, side = 'left', ondown, onhover, onleave, onmenu, ondouble } = $props();

  const info = $derived(typeInfo(inv === ui.player ? 'player' : inv.type));
  const isPlayer = $derived(inv === ui.player);
  const showWeight = $derived(inv.type !== 'shop' && inv.type !== 'crafting' && inv.maxWeight > 0);
  const ratio = $derived(showWeight ? Math.min(1, inv.weight / inv.maxWeight) : 0);
  const level = $derived(ratio >= 0.95 ? 'full' : ratio >= 0.8 ? 'high' : '');
  const used = $derived(inv.items.filter(Boolean).length);
  const sub = $derived.by(() => {
    if (inv.type === 'policeevidence') return String(inv.id || '').replace(/^evidence-/, '#');
    if (inv.type === 'shop') return t('ui_buy');
    if (inv.type === 'crafting') return t('ui_craft');
    if (inv.type === 'inspect') return t('ui_inspect');
    return '';
  });
</script>

<section class="panel tone-{info.tone} {side}">
  <header>
    <span class="pill"><i class="fa-solid fa-{info.icon}"></i></span>
    <div class="titles">
      <div class="row">
        <span class="code mono">{info.code}</span>
        <h2>{titleOf(inv)}</h2>
      </div>
      {#if sub}<span class="sub">{sub}</span>{/if}
    </div>
    <div class="stats mono">
      {#if showWeight}
        <span class="w {level}">{formatKg(inv.weight)}<em>/ {formatKg(inv.maxWeight)} kg</em></span>
      {/if}
      <span class="s">{used}<em>/ {inv.slots}</em></span>
    </div>
    {#if showWeight}
      <span class="bar {level}"><span style:width="{ratio * 100}%"></span></span>
    {/if}
  </header>
  <div class="grid scroll" class:ground={inv.type === 'newdrop'}>
    {#each inv.items as item, i (i)}
      <Slot {inv} index={i} {item} hotkey={isPlayer && i < 5 ? i + 1 : null} {ondown} {onhover} {onleave} {onmenu} {ondouble} />
    {/each}
  </div>
</section>

<style>
  .panel {
    position: relative; display: flex; flex-direction: column; min-height: 0; height: 100%;
    width: calc(var(--slot) * 5 + var(--gap) * 4 + 28px);
    background: var(--card); border: 1px solid var(--line-2); border-radius: var(--radius-lg);
    box-shadow: 0 18px 44px rgba(0, 0, 0, 0.55); overflow: hidden;
    animation: rise 0.18s var(--ease);
  }
  .panel.right { animation-name: rise-r; }
  @keyframes rise { from { opacity: 0; transform: translateX(-14px); } to { opacity: 1; transform: none; } }
  @keyframes rise-r { from { opacity: 0; transform: translateX(14px); } to { opacity: 1; transform: none; } }

  header { position: relative; display: flex; align-items: center; gap: 12px; padding: 14px 14px 16px 18px; border-bottom: 1px solid var(--line); background: linear-gradient(180deg, var(--bg-2), rgba(13, 18, 26, 0.6)); }
  header::before { content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: var(--tone); }
  .pill { flex: none; width: 34px; height: 30px; border-radius: 6px; display: inline-flex; align-items: center; justify-content: center; background: var(--tone); color: var(--bg); font-size: 14px; }
  .titles { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
  .row { display: flex; align-items: baseline; gap: 8px; min-width: 0; }
  .code { flex: none; font-size: 12px; font-weight: 600; letter-spacing: 0.06em; color: var(--tone-text); }
  h2 { margin: 0; font-size: 18px; font-weight: 700; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sub { font-size: 12px; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .stats { flex: none; display: flex; flex-direction: column; align-items: flex-end; gap: 2px; font-size: 13px; font-weight: 600; color: var(--text); }
  .stats em { font-style: normal; color: var(--faint); font-weight: 500; margin-left: 4px; }
  .stats .s { font-size: 11px; color: var(--muted); }
  .w.high { color: var(--warn-text); }
  .w.full { color: var(--danger-text); }
  .bar { position: absolute; left: 18px; right: 14px; bottom: 6px; height: 3px; border-radius: 2px; background: var(--line); overflow: hidden; }
  .bar span { display: block; height: 100%; background: var(--tone); transition: width 0.25s var(--ease); }
  .bar.high span { background: var(--warn); }
  .bar.full span { background: var(--danger); }

  .grid { flex: 1; min-height: 0; display: grid; grid-template-columns: repeat(5, var(--slot)); grid-auto-rows: var(--slot); gap: var(--gap); padding: 14px; align-content: start; }
  .grid.ground { background: repeating-linear-gradient(135deg, rgba(43, 58, 80, 0.06) 0 10px, transparent 10px 20px); }

  .tone-accent { --tone: var(--accent); --tone-text: var(--p2-text); }
  .tone-info { --tone: var(--info); --tone-text: var(--info-text); }
  .tone-warn { --tone: var(--warn); --tone-text: var(--warn-text); }
  .tone-ok { --tone: var(--ok); --tone-text: var(--ok-text); }
  .tone-danger { --tone: var(--danger); --tone-text: var(--danger-text); }
  .tone-doj { --tone: var(--doj); --tone-text: var(--doj-text); }
  .tone-muted { --tone: var(--muted); --tone-text: var(--text-2); }
</style>
