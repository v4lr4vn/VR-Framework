<script>
  import { onMount } from 'svelte';
  import { post } from './lib/nui.js';
  import { place, position, pick } from './lib/layout.js';
  import { iconOf, colorOf } from './lib/icon.js';

  let visible = $state(false);
  let items = $state([]);
  let cursor = $state(false);
  let angle = $state(-Math.PI / 2);
  let hover = $state(-1);
  let menu = $state(false);
  let run = $state(0);

  const placed = $derived(place(items));
  const active = $derived(items.length > 0);

  const reset = () => {
    hover = -1;
    angle = -Math.PI / 2;
  };

  const onMessage = (event) => {
    const msg = event.data;
    if (!msg || typeof msg !== 'object') return;
    if (msg.action === 'target:visible') {
      visible = msg.data === true;
      if (!visible) {
        items = [];
        cursor = false;
        reset();
      }
    } else if (msg.action === 'target:set') {
      const next = Array.isArray(msg.data?.items) ? msg.data.items : [];
      const changed = next.length !== items.length || next.some((n, i) => n.label !== items[i]?.label);
      items = next;
      menu = msg.data?.menu === true;
      if (changed) run += 1;
      if (hover >= placed.length) hover = -1;
    } else if (msg.action === 'target:cursor') {
      cursor = msg.data === true;
      if (!cursor) reset();
    }
  };

  const onMove = (e) => {
    if (!cursor) return;
    const cx = window.innerWidth / 2;
    const cy = window.innerHeight / 2;
    const dx = e.clientX - cx;
    const dy = e.clientY - cy;
    if (Math.hypot(dx, dy) < 12) return;
    angle = Math.atan2(dy, dx);
    hover = pick(placed, angle);
  };

  const onClick = (e) => {
    if (!cursor) return;
    if (e.button === 2) {
      post('close');
      return;
    }
    if (hover < 0) return;
    const entry = placed[hover];
    if (entry) post('select', { index: entry.index + 1 });
  };

  onMount(() => {
    window.addEventListener('message', onMessage);
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mousedown', onClick);
    const block = (e) => e.preventDefault();
    window.addEventListener('contextmenu', block);
    return () => {
      window.removeEventListener('message', onMessage);
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mousedown', onClick);
      window.removeEventListener('contextmenu', block);
    };
  });
</script>

{#if visible}
  <div class="root" class:cursor>
    <div class="reticle" class:active class:cursor>
      <span class="ring"></span>
      <span class="dot"></span>
      {#if cursor}
        <span class="arrow" style:transform="rotate({angle}rad)"><i></i></span>
      {/if}
    </div>
    {#if active && !cursor}
      <div class="hint"><kbd>LMB</kbd><span>{items.length} {items.length === 1 ? 'option' : 'options'}</span></div>
    {/if}
    {#key run}
      {#each placed as entry, i (entry.index)}
        {@const pos = position(entry, items.length)}
        {@const icon = iconOf(entry.item.icon)}
        <div
          class="opt {entry.side}"
          class:hot={hover === i}
          class:back={entry.item.t === '__back'}
          style:--x="{pos.x}px"
          style:--y="{pos.y}px"
          style:--d="{i * 22}ms"
        >
          <span class="ico" style:color={hover === i ? null : colorOf(entry.item.iconColor, null)}>
            {#if icon?.img}<img src={icon.img} alt="" />{:else if icon}<i class={icon.cls}></i>{:else}<i class="fa-solid fa-circle-dot"></i>{/if}
          </span>
          <span class="label">{entry.item.label}</span>
        </div>
      {/each}
    {/key}
  </div>
{/if}

<style>
  .root { position: fixed; inset: 0; pointer-events: none; }
  .root.cursor { pointer-events: auto; cursor: none; }

  .reticle { position: absolute; left: 50%; top: 50%; width: 0; height: 0; }
  .ring {
    position: absolute; left: -15px; top: -15px; width: 30px; height: 30px; border-radius: 50%;
    border: 1.5px solid rgba(230, 237, 245, 0.32); transition: border-color 0.15s, transform 0.2s var(--ease), box-shadow 0.15s;
  }
  .dot {
    position: absolute; left: -4px; top: -4px; width: 8px; height: 8px; transform: rotate(45deg);
    background: rgba(230, 237, 245, 0.7); border-radius: 1.5px; transition: background 0.15s, transform 0.2s var(--ease);
  }
  .reticle.active .ring { border-color: var(--accent); box-shadow: 0 0 0 4px rgba(245, 165, 36, 0.12), 0 0 18px rgba(245, 165, 36, 0.25); animation: breathe 1.6s ease-in-out infinite; }
  .reticle.active .dot { background: var(--accent-2); }
  .reticle.cursor .ring { transform: scale(1.12); animation: none; }
  .arrow { position: absolute; left: 0; top: 0; width: 0; height: 0; transform-origin: 0 0; transition: transform 0.05s linear; }
  .arrow i { position: absolute; left: 21px; top: -5px; width: 0; height: 0; border-top: 5px solid transparent; border-bottom: 5px solid transparent; border-left: 8px solid var(--accent); filter: drop-shadow(0 0 4px rgba(245, 165, 36, 0.6)); }

  .hint {
    position: absolute; left: 50%; top: calc(50% + 26px); transform: translateX(-50%); display: flex; align-items: center; gap: 6px;
    padding: 3px 8px 3px 4px; border-radius: 6px; background: var(--card); border: 1px solid var(--line-2);
    font-family: var(--mono); font-size: 11px; font-weight: 600; color: var(--muted); letter-spacing: 0.06em; text-transform: uppercase;
    animation: fade 0.15s;
  }
  kbd { display: inline-flex; align-items: center; height: 18px; padding: 0 5px; border-radius: 4px; border: 1px solid var(--line-3); border-bottom-width: 2px; background: var(--panel-2); color: var(--accent-2); font-family: var(--mono); font-size: 10px; }

  .opt {
    position: absolute; left: calc(50% + var(--x)); top: calc(50% + var(--y));
    display: flex; align-items: center; gap: 10px; height: 38px; min-width: 150px; max-width: 280px; padding: 0 16px 0 7px;
    border-radius: 7px; background: var(--card); border: 1px solid var(--line-2); box-shadow: 0 8px 22px rgba(0, 0, 0, 0.45);
    white-space: nowrap; transition: border-color 0.12s, background 0.12s;
    animation: pop 0.2s var(--ease) both; animation-delay: var(--d);
  }
  .opt.left { transform: translate(-100%, -50%); }
  .opt.right { transform: translate(0, -50%); }
  .opt.top { transform: translate(-50%, -100%); }
  .opt.bottom { transform: translate(-50%, 0); }
  .opt::after {
    content: ''; position: absolute; width: 8px; height: 8px; background: inherit; border: inherit; border-width: 0;
    transform: rotate(45deg); transition: border-color 0.12s;
  }
  .opt.left::after { right: -5px; top: calc(50% - 4px); border-top: 1px solid var(--line-2); border-right: 1px solid var(--line-2); }
  .opt.right::after { left: -5px; top: calc(50% - 4px); border-bottom: 1px solid var(--line-2); border-left: 1px solid var(--line-2); }
  .opt.top::after { bottom: -5px; left: calc(50% - 4px); border-bottom: 1px solid var(--line-2); border-right: 1px solid var(--line-2); }
  .opt.bottom::after { top: -5px; left: calc(50% - 4px); border-top: 1px solid var(--line-2); border-left: 1px solid var(--line-2); }

  .ico { flex: none; width: 24px; height: 24px; display: inline-flex; align-items: center; justify-content: center; border-radius: 5px; background: var(--panel-2); color: var(--text-2); font-size: 12px; transition: background 0.12s, color 0.12s; }
  .ico img { width: 16px; height: 16px; object-fit: contain; }
  .label { font-size: 15px; font-weight: 600; color: var(--text); overflow: hidden; text-overflow: ellipsis; }
  .opt.back .label { color: var(--muted); }

  .opt.hot { border-color: var(--accent); background: #1f1a10; }
  .opt.hot::after { border-color: var(--accent) !important; }
  .opt.hot .ico { background: var(--accent); color: var(--accent-ink); }

  @keyframes pop { from { opacity: 0; scale: 0.85; } to { opacity: 1; scale: 1; } }
  @keyframes fade { from { opacity: 0; } to { opacity: 1; } }
  @keyframes breathe { 0%, 100% { box-shadow: 0 0 0 4px rgba(245, 165, 36, 0.12), 0 0 18px rgba(245, 165, 36, 0.22); } 50% { box-shadow: 0 0 0 6px rgba(245, 165, 36, 0.06), 0 0 24px rgba(245, 165, 36, 0.32); } }
</style>
