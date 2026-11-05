<script>
  import { onMount } from 'svelte';
  import { on } from '../lib/bus.js';
  import { md } from '../lib/md.js';
  import { TONES } from '../lib/glyphs.js';
  import { settings } from '../lib/settings.svelte.js';
  import { colorOf } from '../lib/icon.js';
  import Glyph from './Glyph.svelte';
  import Icon from './Icon.svelte';

  let notes = $state([]);
  let seq = 0;

  const cfg = $derived(settings.notify);
  const pos = $derived(cfg.position || 'top-right');
  const side = $derived(pos.endsWith('left') || pos === 'left' ? 'from-left' : pos === 'top' || pos === 'bottom' ? 'from-top' : 'from-right');

  const stackStyle = $derived.by(() => {
    const x = `${cfg.offsetX ?? 24}px`;
    const y = `${cfg.offsetY ?? 24}px`;
    const s = [`width:${cfg.width ?? 340}px`];
    if (pos.includes('top')) s.push(`top:${y}`);
    if (pos.includes('bottom')) s.push(`bottom:${y}`);
    if (pos.endsWith('right') || pos === 'right') s.push(`right:${x}`);
    if (pos.endsWith('left') || pos === 'left') s.push(`left:${x}`);
    return s.join(';');
  });

  const remove = (note) => {
    if (note.leaving) return;
    clearTimeout(note.timer);
    note.leaving = true;
    setTimeout(() => {
      notes = notes.filter((n) => n !== note);
    }, 200);
  };

  const arm = (note, duration) => {
    clearTimeout(note.timer);
    note.duration = duration;
    note.run += 1;
    note.timer = setTimeout(() => remove(note), duration);
  };

  const push = (data) => {
    if (!data || typeof data !== 'object') return;
    const type = TONES[data.type] ? data.type : 'primary';
    const title = data.title ? String(data.title) : '';
    const message = data.message ? String(data.message) : '';
    if (!title && !message) return;
    const duration = Math.max(1000, Math.min(Number(data.duration) || cfg.duration || 5000, 60000));
    const key = data.id ? `id:${data.id}` : `${type}|${title}|${message}`;
    const existing = notes.find((n) => n.key === key && !n.leaving);
    if (existing) {
      if (data.id) {
        Object.assign(existing, { type, title, message, code: data.code || null, icon: data.icon || null, iconColor: data.iconColor || null, iconAnimation: data.iconAnimation || null });
      } else {
        existing.count += 1;
      }
      notes = [existing, ...notes.filter((n) => n !== existing)];
      arm(existing, duration);
      return;
    }
    const note = $state({
      id: ++seq, key, type, title, message, count: 1, leaving: false, timer: 0, run: 0, duration,
      code: data.code || null, icon: data.icon || null, iconColor: data.iconColor || null, iconAnimation: data.iconAnimation || null,
    });
    notes = [note, ...notes];
    arm(note, duration);
    const live = notes.filter((n) => !n.leaving);
    for (let i = cfg.maxVisible ?? 3; i < live.length; i++) remove(live[i]);
  };

  onMount(() => on('notify', push));
</script>

<div class="stack {pos} {side}" style={stackStyle} aria-live="polite">
  {#each notes as n, i (n.id)}
    <article class="note t-{n.type}" class:plain={!n.title} class:latest={i === 0 && !n.leaving} class:leaving={n.leaving}>
      <div class="row">
        <span class="pill" style:background={n.iconColor ? colorOf(n.iconColor, null) : null}>
          {#if n.icon}<Icon icon={n.icon} animation={n.iconAnimation} size={12} />{:else}<Glyph name={n.type} />{/if}
        </span>
        <span class="code">{(n.code || TONES[n.type]).toUpperCase()}</span>
        {#if n.title}<span class="title">{@html md(n.title).replace(/^<p>|<\/p>$/g, '')}</span>{/if}
        {#if n.count > 1}<span class="count">x{n.count}</span>{/if}
      </div>
      {#if n.message}<div class="msg md">{@html md(n.message)}</div>{/if}
      {#key n.run}<span class="bar" style:animation-duration="{n.duration}ms"></span>{/key}
    </article>
  {/each}
</div>

<style>
  .stack { position: fixed; display: flex; flex-direction: column; gap: 10px; pointer-events: none; z-index: 40; }
  .stack.bottom-right, .stack.bottom-left, .stack.bottom { flex-direction: column-reverse; }
  .stack.top, .stack.bottom { left: 50%; transform: translateX(-50%); }
  .stack.right, .stack.left { top: 50%; transform: translateY(-50%); }

  .note {
    position: relative; overflow: hidden; display: flex; flex-direction: column; gap: 5px;
    padding: 12px 14px 14px; border-radius: var(--radius-lg); background: var(--card);
    border: 1px solid var(--line-2); box-shadow: 0 10px 28px rgba(0, 0, 0, 0.5);
    animation: enter-right 0.22s ease-out; transition: opacity 0.18s ease, transform 0.18s ease;
  }
  .from-left .note { animation-name: enter-left; }
  .from-top .note { animation-name: enter-down; }
  .note.latest { border-color: var(--tone); }
  .note.leaving { opacity: 0; transform: translateX(24px); }
  .from-left .note.leaving { transform: translateX(-24px); }
  .from-top .note.leaving { transform: translateY(-12px); }
  @keyframes enter-right { from { transform: translateX(24px); opacity: 0; } to { transform: none; opacity: 1; } }
  @keyframes enter-left { from { transform: translateX(-24px); opacity: 0; } to { transform: none; opacity: 1; } }
  @keyframes enter-down { from { transform: translateY(-12px); opacity: 0; } to { transform: none; opacity: 1; } }

  .row { display: flex; align-items: center; gap: 8px; min-width: 0; }
  .pill { flex: none; display: inline-flex; align-items: center; justify-content: center; width: 24px; height: 20px; border-radius: 4px; background: var(--tone); color: var(--bg); }
  .code { flex: none; font-family: var(--mono); font-weight: 600; font-size: 13px; letter-spacing: 0.02em; color: var(--tone-text); }
  .title { min-width: 0; font-weight: 700; font-size: 16px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .count { margin-left: auto; flex: none; font-family: var(--mono); font-size: 12px; font-weight: 500; color: var(--faint); }
  .msg {
    color: var(--text-2); font-size: 14px; line-height: 1.35; overflow-wrap: anywhere;
    display: -webkit-box; -webkit-line-clamp: 4; line-clamp: 4; -webkit-box-orient: vertical; overflow: hidden;
  }
  .note.plain .msg { color: var(--text); font-size: 15px; font-weight: 500; }
  .bar {
    position: absolute; left: 0; bottom: 0; height: 2px; width: 100%; background: var(--tone);
    transform-origin: left; animation-name: shrink; animation-timing-function: linear; animation-fill-mode: forwards;
  }
  @keyframes shrink { from { transform: scaleX(1); } to { transform: scaleX(0); } }

  .t-primary { --tone: var(--accent); --tone-text: var(--p2-text); }
  .t-warning { --tone: var(--warn); --tone-text: var(--warn-text); }
  .t-info { --tone: var(--info); --tone-text: var(--info-text); }
  .t-success { --tone: var(--ok); --tone-text: var(--ok-text); }
  .t-error { --tone: var(--danger); --tone-text: var(--danger-text); }
  .t-police { --tone: var(--info); --tone-text: var(--info-text); }
  .t-ems { --tone: var(--ems); --tone-text: var(--ems-text); }
  .t-doj { --tone: var(--doj); --tone-text: var(--doj-text); }
</style>
