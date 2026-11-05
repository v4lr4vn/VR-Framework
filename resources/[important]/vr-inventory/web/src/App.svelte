<script>
  import { onMount } from 'svelte';
  import Panel from './ui/Panel.svelte';
  import Controls from './ui/Controls.svelte';
  import Tooltip from './ui/Tooltip.svelte';
  import ContextMenu from './ui/ContextMenu.svelte';
  import Hotbar from './ui/Hotbar.svelte';
  import ItemNotes from './ui/ItemNotes.svelte';
  import Help from './ui/Help.svelte';
  import { post } from './lib/nui.js';
  import { ui, normaliseInventory, applySlots, imageOf, readOnly, closeInventory } from './lib/state.svelte.js';
  import { transfer, quickMove, useSlot, giveSlot, amountFor, copyText } from './lib/actions.js';

  let pending = null;
  let noteSeq = 0;
  let toastTimer = 0;
  let toastShown = $state(null);

  const invFromEl = (el) => (el.dataset.inv === 'player' ? ui.player : ui.right);

  const pushNote = (data) => {
    if (!Array.isArray(data) || !data[0]) return;
    const note = { id: ++noteSeq, item: data[0], key: data[1], count: data[2], leaving: false };
    ui.notes = [note, ...ui.notes].slice(0, 5);
    setTimeout(() => {
      const n = ui.notes.find((x) => x.id === note.id);
      if (n) n.leaving = true;
      setTimeout(() => (ui.notes = ui.notes.filter((x) => x.id !== note.id)), 220);
    }, 3000);
  };

  const handlers = {
    init(data) {
      ui.locale = data.locale || {};
      ui.items = data.items || {};
      ui.imagepath = data.imagepath || ui.imagepath;
      ui.keys = data.keys || [];
      const player = normaliseInventory({ ...(data.player || {}), type: 'player' }, 'player');
      player.id = 'player';
      ui.player = player;
      ui.ready = true;
    },
    open(data) {
      if (!data) return;
      if (data.left) {
        const player = normaliseInventory({ ...data.left, type: 'player' }, 'player');
        player.id = 'player';
        ui.player = player;
      }
      if ('right' in data) ui.right = data.right ? normaliseInventory(data.right) : null;
      ui.open = true;
      ui.menu = null;
      ui.tooltip = null;
      ui.drag = null;
      ui.busy = false;
    },
    close() {
      ui.open = false;
      ui.right = null;
      ui.menu = null;
      ui.tooltip = null;
      ui.drag = null;
      ui.help = false;
      ui.busy = false;
      pending = null;
    },
    slots: applySlots,
    hotbar() { ui.hotbar = Date.now(); },
    itemNotify: pushNote,
    displayMetadata(data) {
      if (!Array.isArray(data)) return;
      for (const entry of data) if (entry && entry.metadata) ui.meta[entry.metadata] = entry.value;
    },
  };

  $effect(() => {
    const toast = ui.toast;
    if (!toast) return;
    toastShown = toast;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => (toastShown = null), 2400);
  });

  const onDown = (e, inv, slot) => {
    if (e.button !== 0 || !ui.open) return;
    ui.menu = null;
    const item = inv && inv.items[slot - 1];
    if (!item || readOnly(inv) || ui.busy) return;
    if (e.altKey && inv === ui.player) {
      e.preventDefault();
      return useSlot(slot);
    }
    if (e.ctrlKey) {
      e.preventDefault();
      return quickMove(inv, slot, e.shiftKey);
    }
    pending = { inv, slot, x: e.clientX, y: e.clientY, half: e.shiftKey };
  };

  const onHover = (e, inv, slot) => {
    if (ui.drag && ui.drag.active) return;
    ui.tooltip = { inv, slot, x: e.clientX, y: e.clientY };
  };

  const onLeave = () => {
    ui.tooltip = null;
  };

  const onMenu = (e, inv, slot) => {
    if (!ui.open || readOnly(inv) || (inv !== ui.player && ['shop', 'crafting'].includes(inv.type))) return;
    ui.tooltip = null;
    ui.menu = { inv, slot, x: e.clientX, y: e.clientY };
  };

  const onDouble = (inv, slot) => {
    if (inv === ui.player) useSlot(slot);
    else if (!readOnly(inv)) quickMove(inv, slot, false);
  };

  const locate = (x, y) => {
    const el = document.elementFromPoint(x, y);
    if (!el) return { over: null, zone: null };
    const slotEl = el.closest('[data-slot]');
    if (slotEl) {
      const inv = invFromEl(slotEl);
      return { over: inv ? { inv, slot: Number(slotEl.dataset.slot) } : null, zone: null };
    }
    const zoneEl = el.closest('[data-drop]');
    return { over: null, zone: zoneEl ? zoneEl.dataset.drop : null };
  };

  const onMove = (e) => {
    if (ui.tooltip && !(ui.drag && ui.drag.active)) {
      ui.tooltip.x = e.clientX;
      ui.tooltip.y = e.clientY;
    }
    if (!pending) return;
    if (!ui.drag) {
      if (Math.hypot(e.clientX - pending.x, e.clientY - pending.y) < 5) return;
      const item = pending.inv.items[pending.slot - 1];
      if (!item) {
        pending = null;
        return;
      }
      ui.tooltip = null;
      ui.drag = { active: true, inv: pending.inv, slot: pending.slot, item, count: amountFor(item, pending.half), x: e.clientX, y: e.clientY, over: null, overZone: null };
    }
    ui.drag.x = e.clientX;
    ui.drag.y = e.clientY;
    const { over, zone } = locate(e.clientX, e.clientY);
    ui.drag.over = over;
    ui.drag.overZone = zone;
  };

  const onUp = () => {
    const drag = ui.drag;
    pending = null;
    if (!drag) return;
    ui.drag = null;
    if (drag.over && drag.over.inv) {
      if (readOnly(drag.over.inv)) return;
      transfer(drag.inv, drag.slot, drag.over.inv, drag.over.slot, drag.count);
    } else if (drag.overZone && drag.inv === ui.player) {
      if (drag.overZone === 'use') useSlot(drag.slot);
      else if (drag.overZone === 'give') giveSlot(drag.slot, drag.count);
    }
  };

  const onKey = (e) => {
    if (!ui.open) return;
    if (e.key === 'Escape') {
      if (e.defaultPrevented) return;
      e.preventDefault();
      if (ui.menu) return (ui.menu = null);
      if (ui.help) return (ui.help = false);
      return closeInventory();
    }
    if ((e.ctrlKey || e.metaKey) && (e.key === 'c' || e.key === 'C') && ui.tooltip) {
      const item = ui.tooltip.inv.items[ui.tooltip.slot - 1];
      const serial = item && item.metadata && item.metadata.serial;
      if (serial) copyText(serial);
    }
  };

  const onPointerDownWindow = (e) => {
    if (ui.menu && !e.target.closest('.menu')) ui.menu = null;
  };

  onMount(() => {
    const onMessage = (event) => {
      const msg = event.data;
      if (!msg || typeof msg !== 'object' || typeof msg.action !== 'string') return;
      const fn = handlers[msg.action];
      if (fn) fn(msg.data);
    };
    window.addEventListener('message', onMessage);
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    window.addEventListener('keydown', onKey);
    window.addEventListener('pointerdown', onPointerDownWindow, true);
    post('uiLoaded');
    return () => {
      window.removeEventListener('message', onMessage);
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
      window.removeEventListener('keydown', onKey);
      window.removeEventListener('pointerdown', onPointerDownWindow, true);
    };
  });
</script>

{#if ui.open && ui.player}
  <div class="screen" role="application" oncontextmenu={(e) => e.preventDefault()}>
    <div class="stage">
      <Panel inv={ui.player} side="left" ondown={onDown} onhover={onHover} onleave={onLeave} onmenu={onMenu} ondouble={onDouble} />
      <Controls />
      {#if ui.right}
        {#key ui.right.id + ':' + ui.right.type}
          <Panel inv={ui.right} side="right" ondown={onDown} onhover={onHover} onleave={onLeave} onmenu={onMenu} ondouble={onDouble} />
        {/key}
      {:else}
        <div class="placeholder"></div>
      {/if}
    </div>
    {#if toastShown}
      {#key toastShown.id}<div class="toast"><i class="fa-solid fa-triangle-exclamation"></i>{toastShown.message}</div>{/key}
    {/if}
  </div>
{/if}

{#if ui.drag && ui.drag.active}
  <div class="ghost" style:left="{ui.drag.x}px" style:top="{ui.drag.y}px">
    <img src={imageOf(ui.drag.item)} alt="" onerror={(e) => (e.currentTarget.style.visibility = 'hidden')} />
    <span class="mono">×{ui.drag.count}</span>
  </div>
{/if}

<Tooltip />
<ContextMenu />
<Help />
<Hotbar />
<ItemNotes />

<style>
  .screen {
    position: fixed; inset: 0; display: flex; align-items: center; justify-content: center;
    background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.35) 0%, rgba(4, 6, 10, 0.78) 100%);
    animation: fade 0.16s ease;
    --slot: clamp(62px, 9.4vh, 102px);
    --gap: clamp(4px, 0.6vh, 7px);
  }
  @keyframes fade { from { opacity: 0; } to { opacity: 1; } }
  .stage { display: flex; align-items: stretch; gap: 18px; height: min(860px, 82vh); }
  .placeholder { width: calc(var(--slot) * 5 + var(--gap) * 4 + 28px); }
  .ghost {
    position: fixed; z-index: 80; pointer-events: none; transform: translate(-50%, -50%);
    width: calc(var(--slot, 90px) * 0.9); height: calc(var(--slot, 90px) * 0.9); display: flex; align-items: center; justify-content: center;
    border-radius: var(--radius); background: rgba(26, 36, 51, 0.75); border: 1px solid var(--accent); box-shadow: 0 10px 24px rgba(0, 0, 0, 0.6);
    --slot: clamp(62px, 9.4vh, 102px);
  }
  .ghost img { max-width: 72%; max-height: 72%; object-fit: contain; }
  .ghost span { position: absolute; right: 6px; top: 4px; font-size: 12px; font-weight: 700; color: var(--accent-2); }
  .toast {
    position: fixed; left: 50%; bottom: 4vh; transform: translateX(-50%); z-index: 45; display: flex; align-items: center; gap: 8px;
    padding: 9px 14px; border-radius: var(--radius-lg); background: var(--danger-bg); border: 1px solid var(--danger-line); color: var(--danger-text);
    font-weight: 600; font-size: 14px; box-shadow: 0 10px 28px rgba(0, 0, 0, 0.5); animation: fade 0.15s ease;
  }
</style>
