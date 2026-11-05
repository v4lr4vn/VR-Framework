<script>
  import Card from './Card.svelte';
  import { pad } from '../lib/api.js';

  let { c, meta, w = 260, live = true } = $props();

  let el;
  let px = $state(50);
  let py = $state(50);
  let rx = $state(0);
  let ry = $state(0);
  let active = $state(false);
  let tx = 0.5;
  let ty = 0.5;
  let frame = 0;

  let name = $derived(meta?.grades?.[c.grade] || '');
  let foil = $derived(c.foil && c.foil !== 'none' ? meta?.foils?.[c.foil] || c.foil : '');
  let glint = $derived(live ? { px, py, active } : null);

  function apply() {
    frame = 0;
    if (!active) return;
    px = tx * 100;
    py = ty * 100;
    ry = (tx - 0.5) * 14;
    rx = -(ty - 0.5) * 14;
  }

  function move(e) {
    if (!live || !el) return;
    const r = el.getBoundingClientRect();
    if (!r.width || !r.height) return;
    tx = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width));
    ty = Math.max(0, Math.min(1, (e.clientY - r.top) / r.height));
    active = true;
    if (!frame) frame = requestAnimationFrame(apply);
  }

  function leave() {
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
    active = false;
    rx = 0;
    ry = 0;
    px = 50;
    py = 50;
  }

  $effect(() => () => {
    if (frame) cancelAnimationFrame(frame);
  });
</script>

<div class="hit" class:active bind:this={el} style="--w:{w}px" onpointermove={move} onpointerleave={leave} role="img" aria-label="{c.name}, graded {c.grade}">
  <div class="slab" style="--px:{px}%; --py:{py}%; --rx:{rx}deg; --ry:{ry}deg">
    <div class="label">
      <div class="ll">
        <span class="co">{meta?.company || 'EGC'}</span>
        <span class="l1">{c.year} {c.setLabel}</span>
        <span class="l2">{c.name}{foil ? ` · ${foil}` : ''}</span>
        <span class="l3 num">{c.set} #{pad(c.number)} · CERT {c.cert}</span>
      </div>
      <div class="gr">
        <span class="gn">{name}</span>
        <span class="g num">{c.grade}</span>
      </div>
    </div>
    <div class="well"><Card {c} {meta} {w} live={false} ext={glint} badge={false} /></div>
  </div>
</div>

<style>
  .hit { width: calc(var(--w) * 1.19 + 6px); perspective: 1100px; flex: none; }
  .slab { position: relative; width: 100%; padding: calc(var(--w) * 0.06); border-radius: calc(var(--w) * 0.06); background: linear-gradient(160deg, rgba(235, 242, 250, 0.32), rgba(200, 212, 226, 0.16) 45%, rgba(235, 242, 250, 0.28)); border: 2px solid rgba(225, 233, 242, 0.65); box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.25), inset 0 calc(var(--w) * 0.01) calc(var(--w) * 0.03) rgba(255, 255, 255, 0.2); display: flex; flex-direction: column; gap: calc(var(--w) * 0.05); transform: rotateX(var(--rx)) rotateY(var(--ry)); transition: transform 0.45s var(--ease); will-change: transform; pointer-events: none; }
  .active .slab { transition: transform 0.12s ease-out; }
  .slab::after { content: ''; position: absolute; inset: 0; border-radius: inherit; background: linear-gradient(115deg, transparent 35%, rgba(255, 255, 255, 0.26) 47%, transparent 57%); background-size: 260% 260%; background-position: var(--px) var(--py); transition: background-position 0.12s ease-out; pointer-events: none; }
  .label { display: flex; align-items: stretch; gap: 8px; padding: calc(var(--w) * 0.035) calc(var(--w) * 0.045); border-radius: calc(var(--w) * 0.02); background: linear-gradient(180deg, #f6f5ef, #e7e5dc); border-top: calc(var(--w) * 0.018) solid #f5a524; color: #141b26; }
  .ll { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 1px; }
  .co { font-weight: 800; font-size: calc(var(--w) * 0.06); letter-spacing: 0.12em; color: #9a5d05; }
  .l1, .l2, .l3 { font-size: calc(var(--w) * 0.042); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .l2 { font-weight: 700; text-transform: uppercase; }
  .l3 { color: #4a5563; font-size: calc(var(--w) * 0.038); }
  .gr { display: flex; flex-direction: column; align-items: flex-end; justify-content: center; }
  .gn { font-size: calc(var(--w) * 0.04); font-weight: 800; text-transform: uppercase; letter-spacing: 0.04em; }
  .g { font-size: calc(var(--w) * 0.16); font-weight: 700; line-height: 1; color: #141b26; }
  .well { display: flex; justify-content: center; align-items: center; padding: calc(var(--w) * 0.035); border-radius: calc(var(--w) * 0.04); background: rgba(255, 255, 255, 0.08); border: 1px solid rgba(255, 255, 255, 0.22); }
</style>
