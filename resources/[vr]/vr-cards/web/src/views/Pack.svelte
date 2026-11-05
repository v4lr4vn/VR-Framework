<script>
  import Card from '../ui/Card.svelte';
  import Flip from '../ui/Flip.svelte';
  import PackArt from '../ui/PackArt.svelte';
  import { nui, errorText } from '../lib/api.js';
  import { sfx } from '../lib/sfx.js';

  let { p, onclose } = $props();

  const ORDER = { common: 1, uncommon: 2, rare: 3, epic: 4, legendary: 5 };
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));

  let data = $state(p);
  let phase = $state('sealed');
  let flipped = $state([]);
  let shaking = $state(-1);
  let bursts = $state({});
  let flash = $state(null);
  let left = $state(0);
  let busy = $state(false);
  let auto = $state(false);
  let err = $state('');
  let muted = $state(sfx.muted);

  let cards = $derived(data.cards || []);
  let meta = $derived(data.meta || {});
  let w = $derived(cards.length > 5 ? 170 : 206);
  let done = $derived(phase === 'dealt' && flipped.length === cards.length && flipped.every(Boolean));
  let best = $derived(cards.reduce((b, c) => (!b || (ORDER[c.rarity] || 0) > (ORDER[b.rarity] || 0) || ((ORDER[c.rarity] || 0) === (ORDER[b.rarity] || 0) && c.foil === 'holo') ? c : b), null));
  let fresh = $derived(cards.filter((c) => c.new).length);

  const particles = Array.from({ length: 22 }, (_, i) => ({ a: (360 / 22) * i + Math.random() * 10, d: 120 + Math.random() * 110, s: 4 + Math.random() * 6, t: 0.7 + Math.random() * 0.5 }));

  async function count() {
    left = Number(await nui('packCount')) || 0;
  }
  count();

  function tear() {
    if (phase !== 'sealed') return;
    sfx.tear();
    phase = 'tearing';
    setTimeout(() => {
      flipped = cards.map(() => false);
      phase = 'dealt';
      cards.forEach((_, i) => setTimeout(() => sfx.deal(), 120 + i * 110));
    }, 700);
  }

  function reveal(i) {
    sfx.flip();
    flipped[i] = true;
    const c = cards[i];
    setTimeout(() => {
      sfx.reveal(c.rarity, c.foil);
      if ((ORDER[c.rarity] || 0) >= 3 || c.foil === 'holo') bursts[i] = Date.now();
      if (c.rarity === 'legendary' || c.rarity === 'epic') {
        flash = c.rarity;
        setTimeout(() => (flash = null), 1100);
      }
    }, 320);
  }

  function flip(i) {
    if (phase !== 'dealt' || flipped[i] || shaking >= 0) return false;
    const c = cards[i];
    if ((ORDER[c.rarity] || 0) >= 4) {
      shaking = i;
      sfx.shake();
      setTimeout(() => {
        shaking = -1;
        reveal(i);
      }, 700);
      return true;
    }
    reveal(i);
    return true;
  }

  async function flipAll() {
    if (auto) return;
    auto = true;
    for (let i = 0; i < cards.length; i++) {
      if (flipped[i]) continue;
      while (shaking >= 0) await wait(100);
      flip(i);
      await wait((ORDER[cards[i].rarity] || 0) >= 4 ? 1500 : 450);
    }
    auto = false;
  }

  async function another() {
    if (busy) return;
    busy = true;
    err = '';
    const r = await nui('nextPack');
    busy = false;
    if (!r || !r.ok) {
      err = errorText(r && r.error);
      return;
    }
    data = r.data;
    flipped = [];
    bursts = {};
    phase = 'sealed';
    count();
  }

  function toggleSound() {
    muted = sfx.toggle();
  }

  const label = (c) => `${meta.rarities?.[c.rarity]?.label || c.rarity}${c.foil && c.foil !== 'none' ? ` · ${meta.foils?.[c.foil] || c.foil}` : ''}`;
</script>

<div class="room" class:flash-epic={flash === 'epic'} class:flash-legendary={flash === 'legendary'}>
  <div class="rays"></div>
  <header class="topbar">
    <div class="title">
      <span class="logo"><i class="fa-solid fa-layer-group"></i></span>
      <div><h1>{data.pack?.label || 'Booster pack'}</h1><p class="sub">{data.pack?.set}</p></div>
    </div>
    <div class="tools">
      <button class="x" onclick={toggleSound} aria-label={muted ? 'Turn sound on' : 'Turn sound off'}><i class="fa-solid {muted ? 'fa-volume-xmark' : 'fa-volume-high'}"></i></button>
      <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
    </div>
  </header>

  <main class="stage">
    {#if phase !== 'dealt'}
      <button class="packbtn" class:tearing={phase === 'tearing'} onclick={tear} aria-label="Tear the pack open">
        <PackArt pack={data.pack} w={250} torn={phase === 'tearing'} />
      </button>
      {#if phase === 'sealed'}<p class="hint big">Click the pack to tear it open</p>{/if}
    {:else}
      <div class="row" style="--n:{cards.length}">
        {#each cards as c, i (c.uid)}
          <div class="slot" style="--i:{i}">
            <button class="cardbtn" class:shake={shaking === i} class:up={flipped[i]} class:hit={flipped[i] && (ORDER[c.rarity] || 0) >= 3} onclick={() => flip(i)} aria-label={flipped[i] ? c.name : 'Flip card'}>
              {#if flipped[i] && c.rarity === 'legendary'}<div class="halo"></div>{/if}
              {#if bursts[i]}
                <div class="burst r-{c.rarity}">
                  {#each particles as pt}
                    <span style="--a:{pt.a}deg; --d:{pt.d}px; --s:{pt.s}px; --t:{pt.t}s"></span>
                  {/each}
                </div>
              {/if}
              <Flip {w} flipped={flipped[i]}>
                <Card {c} {meta} {w} live={flipped[i]} />
              </Flip>
            </button>
            <div class="cap" class:show={flipped[i]}>
              {#if c.new}<span class="chip accent new">New</span>{/if}
              <span class="rl r-{c.rarity}">{label(c)}</span>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </main>

  <footer class="dock">
    {#if phase === 'dealt' && !done}
      <p class="hint">Click a card to flip it</p>
      <button class="btn" disabled={auto} onclick={flipAll}><i class="fa-solid fa-wand-magic-sparkles"></i>Flip all</button>
    {:else if done}
      <div class="sum">
        <span><i class="fa-solid fa-box-open"></i>{cards.length} cards added to your pockets</span>
        {#if fresh}<span class="pos"><i class="fa-solid fa-star"></i>{fresh} new for your collection</span>{/if}
        {#if best}<span>Best pull: <b class="r-{best.rarity} rl">{best.name}</b></span>{/if}
      </div>
      {#if err}<span class="danger-text">{err}</span>{/if}
      {#if left > 0}
        <button class="btn" disabled={busy} onclick={another}><i class="fa-solid fa-rotate"></i>Open another <span class="num">({left} left)</span></button>
      {/if}
      <button class="btn primary" onclick={onclose}><i class="fa-solid fa-check"></i>Done</button>
    {/if}
  </footer>
</div>

<style>
  .room { position: fixed; inset: 0; display: flex; flex-direction: column; background: radial-gradient(ellipse at 50% 45%, rgba(26, 36, 51, 0.88), rgba(6, 9, 13, 0.97) 70%); overflow: hidden; }
  .rays { position: absolute; left: 50%; top: 48%; width: 1800px; height: 1800px; margin: -900px 0 0 -900px; background: repeating-conic-gradient(from 0deg, rgba(245, 165, 36, 0.05) 0deg 6deg, transparent 6deg 18deg); animation: turn 60s linear infinite; pointer-events: none; mask-image: radial-gradient(circle, #000 0%, transparent 60%); -webkit-mask-image: radial-gradient(circle, #000 0%, transparent 60%); }
  @keyframes turn { to { transform: rotate(360deg); } }
  .room::after { content: ''; position: absolute; inset: 0; pointer-events: none; opacity: 0; }
  .flash-epic::after { background: radial-gradient(circle at 50% 50%, rgba(183, 156, 255, 0.45), transparent 60%); animation: flash 1.1s ease-out; }
  .flash-legendary::after { background: radial-gradient(circle at 50% 50%, rgba(255, 213, 107, 0.7), rgba(245, 165, 36, 0.15) 50%, transparent 75%); animation: flash 1.1s ease-out; }
  @keyframes flash { 0% { opacity: 0; } 15% { opacity: 1; } 100% { opacity: 0; } }

  .topbar { position: relative; z-index: 2; display: flex; align-items: center; justify-content: space-between; padding: 18px 24px; }
  .title { display: flex; align-items: center; gap: 12px; }
  .logo { width: 40px; height: 40px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 16px; }
  h1 { font-size: 18px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em; }
  .sub { color: var(--muted); font-size: 12px; }
  .tools { display: flex; gap: 8px; }
  .x { width: 38px; height: 38px; border-radius: var(--radius); border: 1px solid var(--line-3); background: rgba(17, 24, 35, 0.8); color: var(--text-2); }
  .x:hover { color: var(--text); background: var(--panel-2); }

  .stage { position: relative; z-index: 1; flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 22px; min-height: 0; }
  .packbtn { padding: 0; border: 0; background: none; cursor: pointer; animation: bob 2.6s ease-in-out infinite; }
  .packbtn:hover { filter: drop-shadow(0 0 30px rgba(245, 165, 36, 0.35)); }
  .packbtn.tearing { animation: rip 0.7s ease-in forwards; }
  @keyframes bob { 50% { transform: translateY(-8px) rotate(-1deg); } }
  @keyframes rip { 0% { transform: none; } 30% { transform: translateY(6px) scale(1.02); } 100% { transform: translateY(80px) scale(0.92); opacity: 0; } }
  .hint.big { font-size: 15px; color: var(--text-2); letter-spacing: 0.04em; animation: pulse 1.8s ease-in-out infinite; }
  @keyframes pulse { 50% { opacity: 0.45; } }

  .row { display: flex; gap: 22px; align-items: flex-start; justify-content: center; flex-wrap: wrap; max-width: calc(100vw - 60px); }
  .slot { display: flex; flex-direction: column; align-items: center; gap: 12px; animation: deal 0.55s cubic-bezier(0.2, 0.8, 0.25, 1) backwards; animation-delay: calc(var(--i) * 0.11s); }
  @keyframes deal { from { transform: translateY(240px) rotate(-8deg) scale(0.7); opacity: 0; } }
  .cardbtn { position: relative; padding: 0; border: 0; background: none; cursor: pointer; transition: transform 0.2s var(--ease); }
  .cardbtn:not(.up):hover { transform: translateY(-10px); }
  .cardbtn.up { cursor: default; }
  .cardbtn.hit { animation: pop 0.6s 0.3s cubic-bezier(0.2, 1.4, 0.4, 1); }
  @keyframes pop { 40% { transform: scale(1.08); } }
  .shake { animation: shake 0.7s linear; }
  @keyframes shake { 0%, 100% { transform: none; } 10%, 50%, 90% { transform: translateX(-4px) rotate(-1.5deg); } 30%, 70% { transform: translateX(4px) rotate(1.5deg); } }
  .halo { position: absolute; left: 50%; top: 50%; width: 520px; height: 520px; margin: -260px 0 0 -260px; background: repeating-conic-gradient(rgba(255, 213, 107, 0.35) 0deg 8deg, transparent 8deg 20deg); border-radius: 50%; mask-image: radial-gradient(circle, #000 15%, transparent 65%); -webkit-mask-image: radial-gradient(circle, #000 15%, transparent 65%); animation: turn 14s linear infinite; pointer-events: none; z-index: -1; }
  .burst { position: absolute; left: 50%; top: 50%; width: 0; height: 0; pointer-events: none; z-index: 3; }
  .burst span { position: absolute; width: var(--s); height: var(--s); margin: calc(var(--s) / -2); border-radius: 50%; background: #fff; box-shadow: 0 0 8px currentColor; animation: fly var(--t) ease-out forwards; transform: rotate(var(--a)) translateX(0); }
  .burst.r-rare span { color: #5aa9ff; background: #cfe5ff; }
  .burst.r-epic span { color: #b79cff; background: #ece4ff; }
  .burst.r-legendary span { color: #f5a524; background: #fff1c2; }
  .burst.r-uncommon span, .burst.r-common span { color: #ffffff; background: #ffffff; }
  @keyframes fly { from { transform: rotate(var(--a)) translateX(10px); opacity: 1; } to { transform: rotate(var(--a)) translateX(var(--d)); opacity: 0; } }
  .cap { display: flex; flex-direction: column; align-items: center; gap: 6px; min-height: 48px; opacity: 0; transform: translateY(-6px); transition: opacity 0.3s 0.4s, transform 0.3s 0.4s; }
  .cap.show { opacity: 1; transform: none; }
  .new { animation: glow 1.4s ease-in-out infinite; }
  @keyframes glow { 50% { box-shadow: 0 0 12px rgba(245, 165, 36, 0.55); } }
  .rl { font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; color: var(--text-2); }
  .rl.r-uncommon { color: #3dd68c; }
  .rl.r-rare { color: #5aa9ff; }
  .rl.r-epic { color: #b79cff; }
  .rl.r-legendary { color: #ffc85c; }

  .dock { position: relative; z-index: 2; display: flex; align-items: center; justify-content: center; gap: 14px; min-height: 84px; padding: 16px 24px 28px; }
  .dock .btn { height: 40px; font-size: 14px; }
  .sum { display: flex; gap: 18px; align-items: center; margin-right: 10px; color: var(--text-2); font-size: 14px; }
  .sum i { margin-right: 6px; color: var(--muted); }
  .sum .pos i { color: var(--ok); }
</style>
