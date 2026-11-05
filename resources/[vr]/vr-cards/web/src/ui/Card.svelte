<script>
  import { pad } from '../lib/api.js';

  let { c, meta, w = 220, live = false, badge = true, ext = null } = $props();

  let el;
  let px = $state(50);
  let py = $state(50);
  let rx = $state(0);
  let ry = $state(0);
  let active = $state(false);
  let broken = $state(false);
  let tx = 0.5;
  let ty = 0.5;
  let frame = 0;

  let on = $derived(ext ? ext.active === true : active);
  let PX = $derived(ext ? ext.px : px);
  let PY = $derived(ext ? ext.py : py);
  let RX = $derived(ext ? 0 : rx);
  let RY = $derived(ext ? 0 : ry);
  let rar = $derived(meta?.rarities?.[c.rarity] || { label: c.rarity, color: '#AAB4C0' });
  let grp = $derived(meta?.groups?.[c.group] || { label: c.group, icon: 'user', color: '#8A9AB0' });
  let small = $derived(w < 150);
  let tiny = $derived(w < 110);
  let initials = $derived((c.name || '?').split(/\s+/).map((s) => s[0] || '').join('').slice(0, 2).toUpperCase());

  function apply() {
    frame = 0;
    if (!active) return;
    px = tx * 100;
    py = ty * 100;
    ry = (tx - 0.5) * 18;
    rx = -(ty - 0.5) * 18;
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

<div
  class="card r-{c.rarity} f-{c.foil || 'none'}"
  class:active={on}
  class:small
  class:tiny
  class:live
  bind:this={el}
  style="--w:{w}px; --rc:{rar.color}; --gc:{grp.color}"
  onpointermove={move}
  onpointerleave={leave}
  role="img"
  aria-label="{c.name}, {rar.label}"
>
  <div class="tilt" style="--px:{PX}%; --py:{PY}%; --rx:{RX}deg; --ry:{RY}deg">
    <div class="face">
      <div class="frame">
        <header>
          <span class="nm">{c.name}</span>
          <span class="gem" title={rar.label}><i class="fa-solid fa-diamond"></i></span>
        </header>
        <div class="art">
          {#if c.image && !broken}
            <img src="../images/{c.image}" alt="" onerror={() => (broken = true)} />
          {:else}
            <div class="ph">
              <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMax slice" aria-hidden="true">
                <circle cx="50" cy="40" r="19" />
                <path d="M12 100 C14 72 30 62 50 62 C70 62 86 72 88 100 Z" />
              </svg>
              <span class="ini">{initials}</span>
            </div>
          {/if}
          {#if !tiny}<span class="grp"><i class="fa-solid fa-{grp.icon}"></i>{grp.label}</span>{/if}
        </div>
        <div class="ttl">{c.title}</div>
        {#if !small}<p class="qt">“{c.quote}”</p>{/if}
        <footer>
          <span class="num">{c.set} {pad(c.number)}/{pad(c.total)}</span>
          {#if !tiny}<span class="rl">{rar.label}</span>{/if}
          {#if c.serial && !small}<span class="num">#{c.serial}</span>{/if}
        </footer>
      </div>
      {#if c.foil && c.foil !== 'none'}
        <div class="shine idle"></div>
        {#if live || ext}<div class="shine live"></div>{/if}
      {/if}
      <div class="glare"></div>
    </div>
    {#if badge && c.grade}<span class="gbadge num">{meta?.company || 'EGC'} {c.grade}</span>{/if}
  </div>
</div>

<style>
  .card { position: relative; width: var(--w); height: calc(var(--w) * 1.4); border-radius: calc(var(--w) * 0.055); perspective: 900px; flex: none; user-select: none; }
  .tilt { position: absolute; inset: 0; border-radius: inherit; transform: rotateX(var(--rx)) rotateY(var(--ry)); transition: transform 0.45s var(--ease); will-change: transform; box-shadow: 0 calc(var(--w) * 0.04) calc(var(--w) * 0.1) rgba(0, 0, 0, 0.55); pointer-events: none; }
  .active .tilt { transition: transform 0.12s ease-out; }
  .face { position: absolute; inset: 0; border-radius: inherit; overflow: hidden; background: var(--rc); }
  .r-rare .face { background: linear-gradient(140deg, #9cc8ff, #2f6fd0 45%, #5aa9ff); }
  .r-epic .face { background: linear-gradient(140deg, #e7dcff, #7b55e0 40%, #c4a8ff 70%, #5b3bc4); }
  .r-legendary .face::before { content: ''; position: absolute; inset: -60%; background: conic-gradient(#f5a524, #fff3c4, #f5a524, #9a5d05, #ffd56b, #f5a524); animation: spin 5s linear infinite; }
  .r-rare .tilt { box-shadow: 0 0 calc(var(--w) * 0.08) -2px rgba(90, 169, 255, 0.55), 0 calc(var(--w) * 0.04) calc(var(--w) * 0.1) rgba(0, 0, 0, 0.55); }
  .r-epic .tilt { box-shadow: 0 0 calc(var(--w) * 0.1) 0 rgba(183, 156, 255, 0.6), 0 calc(var(--w) * 0.04) calc(var(--w) * 0.1) rgba(0, 0, 0, 0.55); }
  .r-legendary .tilt { box-shadow: 0 0 calc(var(--w) * 0.14) 2px rgba(245, 165, 36, 0.65), 0 calc(var(--w) * 0.04) calc(var(--w) * 0.1) rgba(0, 0, 0, 0.55); }
  @keyframes spin { to { transform: rotate(360deg); } }

  .frame { position: absolute; inset: calc(var(--w) * 0.028); border-radius: calc(var(--w) * 0.035); background: linear-gradient(180deg, #121a26, #0b1018 70%); display: flex; flex-direction: column; padding: calc(var(--w) * 0.035); gap: calc(var(--w) * 0.025); overflow: hidden; }
  header { display: flex; align-items: center; gap: calc(var(--w) * 0.03); }
  .nm { flex: 1; min-width: 0; font-size: calc(var(--w) * 0.075); font-weight: 700; text-transform: uppercase; letter-spacing: 0.02em; color: #f3f6fa; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1.15; }
  .gem { color: var(--rc); font-size: calc(var(--w) * 0.06); filter: drop-shadow(0 0 calc(var(--w) * 0.02) var(--rc)); }
  .r-legendary .gem { color: #ffd56b; }

  .art { position: relative; flex: 0 0 52%; border-radius: calc(var(--w) * 0.025); overflow: hidden; background: linear-gradient(rgba(13, 18, 26, 0.5), rgba(13, 18, 26, 0.5)), radial-gradient(circle at 50% 28%, var(--gc), #0d121a 72%); border: calc(var(--w) * 0.008) solid rgba(255, 255, 255, 0.12); }
  .art img { width: 100%; height: 100%; object-fit: cover; display: block; }
  .ph { position: absolute; inset: 0; background: repeating-linear-gradient(135deg, rgba(255, 255, 255, 0.035) 0 calc(var(--w) * 0.02), transparent calc(var(--w) * 0.02) calc(var(--w) * 0.05)); }
  .ph svg { position: absolute; inset: 0; width: 100%; height: 100%; fill: rgba(5, 8, 12, 0.55); }
  .ini { position: absolute; left: 0; right: 0; top: 18%; text-align: center; font-family: var(--mono); font-weight: 600; font-size: calc(var(--w) * 0.12); color: rgba(255, 255, 255, 0.85); letter-spacing: 0.05em; text-shadow: 0 2px 8px rgba(0, 0, 0, 0.6); }
  .grp { position: absolute; left: calc(var(--w) * 0.03); bottom: calc(var(--w) * 0.03); display: inline-flex; align-items: center; gap: calc(var(--w) * 0.02); padding: calc(var(--w) * 0.01) calc(var(--w) * 0.03); border-radius: 999px; background: rgba(8, 12, 18, 0.78); border: 1px solid var(--gc); color: var(--gc); font-size: calc(var(--w) * 0.038); font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; }
  .ttl { font-size: calc(var(--w) * 0.05); font-weight: 700; color: var(--rc); text-transform: uppercase; letter-spacing: 0.08em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .r-legendary .ttl { color: #ffd56b; }
  .r-common .ttl { color: #c3ceda; }
  .qt { flex: 1; margin: 0; font-size: calc(var(--w) * 0.043); line-height: 1.3; color: #aebbcb; font-style: italic; overflow: hidden; }
  footer { margin-top: auto; display: flex; justify-content: space-between; align-items: center; gap: calc(var(--w) * 0.02); padding-top: calc(var(--w) * 0.02); border-top: 1px solid rgba(255, 255, 255, 0.08); font-size: calc(var(--w) * 0.036); color: #8a9ab0; white-space: nowrap; }
  .rl { text-transform: uppercase; letter-spacing: 0.08em; font-weight: 700; color: var(--rc); }
  .small .frame { gap: calc(var(--w) * 0.03); }
  .small .art { flex-basis: 60%; }
  .small .nm { font-size: calc(var(--w) * 0.085); }
  .small .ttl { font-size: calc(var(--w) * 0.06); }
  .small footer { font-size: calc(var(--w) * 0.05); }
  .tiny .nm { font-size: calc(var(--w) * 0.095); }
  .tiny footer { justify-content: center; font-size: calc(var(--w) * 0.075); }

  .shine, .glare { position: absolute; inset: 0; border-radius: inherit; pointer-events: none; }
  .shine { transition: opacity 0.35s var(--ease); }
  .f-shiny .shine { background: linear-gradient(115deg, transparent 25%, rgba(255, 255, 255, 0) 38%, rgba(255, 255, 255, 0.6) 50%, rgba(255, 255, 255, 0) 62%, transparent 75%); background-size: 300% 300%; mix-blend-mode: overlay; }
  .f-shiny .shine.idle { animation: sweep 3.8s ease-in-out infinite alternate; }
  .f-shiny .shine.live { opacity: 0; background-position: var(--px) var(--py); transition: opacity 0.35s var(--ease), background-position 0.12s ease-out; }
  .active.f-shiny .shine.idle { opacity: 0; }
  .active.f-shiny .shine.live { opacity: 1; }
  .small.f-shiny .shine.idle { opacity: 0.7; }
  .f-holo .shine {
    background:
      radial-gradient(circle at 20% 30%, rgba(255, 255, 255, 0.8) 0 1px, transparent 2px),
      radial-gradient(circle at 70% 60%, rgba(255, 255, 255, 0.7) 0 1px, transparent 2px),
      radial-gradient(circle at 40% 80%, rgba(255, 255, 255, 0.6) 0 1px, transparent 2px),
      repeating-linear-gradient(115deg, rgba(255, 40, 120, 0.6) 0%, rgba(255, 210, 40, 0.6) 6%, rgba(40, 255, 160, 0.6) 12%, rgba(40, 190, 255, 0.6) 18%, rgba(170, 90, 255, 0.6) 24%, rgba(255, 40, 120, 0.6) 30%);
    background-size: 18% 14%, 23% 19%, 29% 23%, 400% 400%;
    mix-blend-mode: color-dodge;
    filter: saturate(1.5) brightness(0.95);
  }
  .f-holo .shine.idle { opacity: 0.5; animation: holo 7s linear infinite; }
  .f-holo .shine.live { opacity: 0; background-position: 0 0, 0 0, 0 0, var(--px) var(--py); transition: opacity 0.35s var(--ease), background-position 0.12s ease-out; }
  .active.f-holo .shine.idle { opacity: 0; }
  .active.f-holo .shine.live { opacity: 0.5; }
  .small.f-holo .shine.idle { opacity: 0.32; }
  .f-holo .art::after { content: ''; position: absolute; inset: 0; background: repeating-linear-gradient(115deg, rgba(255, 40, 120, 0.5) 0%, rgba(255, 210, 40, 0.5) 6%, rgba(40, 255, 160, 0.5) 12%, rgba(40, 190, 255, 0.5) 18%, rgba(170, 90, 255, 0.5) 24%, rgba(255, 40, 120, 0.5) 30%); background-size: 400% 400%; mix-blend-mode: color-dodge; opacity: 0.4; animation: holo2 7s linear infinite; }
  .small.f-holo .art::after { opacity: 0.22; }
  .glare { background: radial-gradient(circle at var(--px) var(--py), rgba(255, 255, 255, 0.45), transparent 48%); mix-blend-mode: soft-light; opacity: 0; transition: opacity 0.35s var(--ease); }
  .active .glare { opacity: 1; }
  @keyframes sweep { from { background-position: 0% 0%; } to { background-position: 100% 100%; } }
  @keyframes holo { from { background-position: 0 0, 0 0, 0 0, 0% 50%; } to { background-position: 0 0, 0 0, 0 0, 400% 50%; } }
  @keyframes holo2 { from { background-position: 0% 50%; } to { background-position: 400% 50%; } }
  .gbadge { position: absolute; top: calc(var(--w) * -0.04); right: calc(var(--w) * -0.04); padding: 2px 6px; border-radius: 4px; background: #f2f2ee; color: #121a26; font-size: 10px; font-weight: 700; border: 2px solid var(--accent); box-shadow: 0 2px 6px rgba(0, 0, 0, 0.5); }
</style>
