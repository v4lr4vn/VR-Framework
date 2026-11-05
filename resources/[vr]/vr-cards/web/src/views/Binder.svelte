<script>
  import Card from '../ui/Card.svelte';
  import Viewer from './Viewer.svelte';
  import { call, errorText } from '../lib/api.js';
  import { sfx } from '../lib/sfx.js';

  let { p, onclose } = $props();

  let b = $state(p);
  let spread = $state(0);
  let pick = $state(null);
  let moving = $state(null);
  let viewing = $state(null);
  let editing = $state(false);
  let title = $state(p.title);
  let busy = $state(false);
  let toast = $state(null);
  let dir = $state(1);
  let timer;

  const per = p.perPage;
  const spreads = Math.ceil(p.pages / 2);
  const CW = 100;

  let pages = $derived([spread * 2, spread * 2 + 1].filter((n) => n < b.pages));
  let count = $derived(Object.keys(b.slots).length);
  let progress = $derived.by(() => {
    const owned = {};
    for (const v of Object.values(b.slots)) {
      owned[v.setId] = owned[v.setId] || new Set();
      owned[v.setId].add(v.id);
    }
    return (b.progress || []).map((s) => ({ ...s, owned: owned[s.id] ? owned[s.id].size : 0 }));
  });
  let picked = $derived(pick?.kind === 'slot' ? b.slots[String(pick.slot)] : pick?.kind === 'hand' ? b.hand.find((c) => c.uid === pick.uid) : null);

  function say(text, kind = 'ok') {
    clearTimeout(timer);
    toast = { text, kind };
    timer = setTimeout(() => (toast = null), 2600);
  }

  const slotOf = (page, i) => page * per + i + 1;

  function go(d) {
    const n = Math.max(0, Math.min(spreads - 1, spread + d));
    if (n === spread) return;
    dir = d;
    spread = n;
    sfx.flip();
  }

  async function run(action, data) {
    if (busy) return null;
    busy = true;
    const r = await call(action, { id: b.id, ...data });
    busy = false;
    if (!r.ok) {
      say(errorText(r.error), 'err');
      return null;
    }
    return r.data;
  }

  async function put(uid, slot) {
    const r = await run('binder.put', { uid, slot });
    if (!r) return;
    b.slots[String(slot)] = r.card;
    b.hand = b.hand.filter((c) => c.uid !== uid);
    pick = null;
    sfx.place();
  }

  async function take(slot) {
    const r = await run('binder.take', { slot });
    if (!r) return;
    delete b.slots[String(slot)];
    b.hand = [...b.hand, r.card];
    pick = null;
    sfx.place();
    say(`${r.card.name} is back in your pockets`);
  }

  async function moveTo(slot) {
    const from = moving;
    moving = null;
    if (from === slot) return;
    const r = await run('binder.move', { from, to: slot });
    if (!r) return;
    const a = b.slots[String(from)];
    const c = b.slots[String(slot)];
    if (c) b.slots[String(from)] = c;
    else delete b.slots[String(from)];
    b.slots[String(slot)] = a;
    pick = null;
    sfx.place();
  }

  function firstEmpty() {
    for (const page of pages) for (let i = 0; i < per; i++) if (!b.slots[String(slotOf(page, i))]) return slotOf(page, i);
    for (let s = 1; s <= b.capacity; s++) if (!b.slots[String(s)]) return s;
    return null;
  }

  function store(uid) {
    const s = firstEmpty();
    if (!s) return say('This binder is full', 'err');
    const page = Math.floor((s - 1) / per);
    const sp = Math.floor(page / 2);
    if (sp !== spread) {
      dir = sp > spread ? 1 : -1;
      spread = sp;
    }
    put(uid, s);
  }

  function pocket(slot) {
    const card = b.slots[String(slot)];
    if (moving) return moveTo(slot);
    if (pick?.kind === 'hand') {
      if (card) return say('That pocket is taken', 'err');
      return put(pick.uid, slot);
    }
    pick = card ? (pick?.kind === 'slot' && pick.slot === slot ? null : { kind: 'slot', slot }) : null;
  }

  function choose(c) {
    moving = null;
    pick = pick?.kind === 'hand' && pick.uid === c.uid ? null : { kind: 'hand', uid: c.uid };
  }

  async function rename() {
    editing = false;
    const t = title.trim();
    if (!t || t === b.title) {
      title = b.title;
      return;
    }
    const r = await run('binder.rename', { title: t });
    if (r) b.title = title = r.title;
    else title = b.title;
  }

  function key(e) {
    if (viewing || editing) return;
    if (e.key === 'ArrowRight') go(1);
    if (e.key === 'ArrowLeft') go(-1);
  }
</script>

<svelte:window onkeydown={key} />

<div class="room">
  <section class="binder" aria-label="Card binder">
    <header>
      <span class="logo"><i class="fa-solid fa-book"></i></span>
      <div class="title">
        {#if editing}
          <input class="input" maxlength="32" bind:value={title} onblur={rename} onkeydown={(e) => e.key === 'Enter' && e.currentTarget.blur()} />
        {:else}
          <button class="tbtn" onclick={() => (editing = true)} title="Rename"><h1>{b.title}</h1><i class="fa-solid fa-pen"></i></button>
        {/if}
        <p class="sub"><span class="num">{count}/{b.capacity}</span> cards stored</p>
      </div>
      <div class="sets">
        {#each progress as s}
          <div class="set" title={s.label}>
            <span class="code num">{s.code}</span>
            <div class="bar" class:ok={s.owned === s.total}><span style="width:{s.total ? (s.owned / s.total) * 100 : 0}%"></span></div>
            <span class="num">{s.owned}/{s.total}</span>
          </div>
        {/each}
      </div>
      <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
    </header>

    <div class="bookrow">
      <button class="nav" disabled={spread === 0} onclick={() => go(-1)} aria-label="Previous pages"><i class="fa-solid fa-chevron-left"></i></button>
      {#key spread}
        <div class="book" style="--dir:{dir}">
          {#each pages as page, side}
            <div class="page" class:left={side === 0} class:right={side === 1}>
              <div class="grid">
                {#each Array(per) as _, i}
                  {@const slot = slotOf(page, i)}
                  {@const card = b.slots[String(slot)]}
                  <button
                    class="pocket"
                    class:filled={!!card}
                    class:sel={pick?.kind === 'slot' && pick.slot === slot}
                    class:target={(pick?.kind === 'hand' && !card) || (moving && moving !== slot)}
                    onclick={() => pocket(slot)}
                    aria-label={card ? card.name : `Empty pocket ${slot}`}
                  >
                    {#if card}
                      <Card c={card} meta={b.meta} w={CW} />
                    {:else}
                      <span class="pn num">{slot}</span>
                    {/if}
                    <span class="sleeve"></span>
                  </button>
                {/each}
              </div>
              <span class="pnum num">Page {page + 1}</span>
            </div>
          {/each}
          <div class="spine"></div>
        </div>
      {/key}
      <button class="nav" disabled={spread >= spreads - 1} onclick={() => go(1)} aria-label="Next pages"><i class="fa-solid fa-chevron-right"></i></button>
    </div>

    <div class="actions">
      {#if moving}
        <span class="hint"><i class="fa-solid fa-arrows-up-down-left-right"></i> Click the pocket to move it to. Filled pockets swap.</span>
        <button class="btn small ghost" onclick={() => (moving = null)}>Cancel</button>
      {:else if picked && pick.kind === 'slot'}
        <span class="pk"><b>{picked.name}</b> <span class="hint">pocket {pick.slot}</span></span>
        <button class="btn small" onclick={() => (viewing = picked)}><i class="fa-solid fa-magnifying-glass"></i>Inspect</button>
        <button class="btn small" onclick={() => (moving = pick.slot)}><i class="fa-solid fa-arrows-up-down-left-right"></i>Move</button>
        <button class="btn small" disabled={busy} onclick={() => take(pick.slot)}><i class="fa-solid fa-hand"></i>Take out</button>
      {:else if picked && pick.kind === 'hand'}
        <span class="pk"><b>{picked.name}</b> <span class="hint">click an empty pocket, or</span></span>
        <button class="btn small primary" disabled={busy} onclick={() => store(picked.uid)}><i class="fa-solid fa-arrow-down-short-wide"></i>Store in the next free pocket</button>
        <button class="btn small" onclick={() => (viewing = picked)}><i class="fa-solid fa-magnifying-glass"></i>Inspect</button>
      {:else}
        <span class="hint">Pick a card below to store it, or a card in the binder to inspect, move or take it out. Arrow keys turn the pages.</span>
      {/if}
    </div>

    <div class="tray">
      <span class="label">In your pockets <span class="num">({b.hand.length})</span></span>
      <div class="cards scroll">
        {#each b.hand as c (c.uid)}
          <button class="tc" class:sel={pick?.kind === 'hand' && pick.uid === c.uid} onclick={() => choose(c)} aria-label={c.name}>
            <Card {c} meta={b.meta} w={88} />
          </button>
        {/each}
        {#if !b.hand.length}<div class="empty"><i class="fa-solid fa-hand"></i>No cards on you</div>{/if}
      </div>
    </div>

    {#if toast}<div class="toast {toast.kind}" role="status"><i class="fa-solid {toast.kind === 'err' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>{toast.text}</div>{/if}
  </section>
</div>

{#if viewing}
  <Viewer c={viewing} meta={b.meta} onclose={() => (viewing = null)} />
{/if}

<style>
  .room { position: fixed; inset: 0; display: grid; place-items: center; background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.6), rgba(6, 9, 13, 0.92)); }
  .binder { position: relative; display: flex; flex-direction: column; gap: 10px; width: 900px; max-width: calc(100vw - 24px); }
  header { display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-radius: var(--radius-lg); background: var(--card); border: 1px solid var(--line-2); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 15px; }
  .title { flex: 1; min-width: 0; }
  .tbtn { display: inline-flex; align-items: center; gap: 8px; padding: 0; border: 0; background: none; color: inherit; }
  .tbtn i { font-size: 11px; color: var(--faint); }
  .tbtn:hover i { color: var(--accent); }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .title .input { height: 30px; font-size: 15px; max-width: 280px; }
  .sub { color: var(--muted); font-size: 12px; }
  .sets { display: flex; gap: 12px; }
  .set { display: grid; grid-template-columns: auto 90px auto; align-items: center; gap: 8px; font-size: 12px; color: var(--text-2); }
  .code { color: var(--accent-2); font-weight: 600; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }

  .bookrow { display: flex; align-items: center; justify-content: center; gap: 12px; }
  .nav { width: 40px; height: 120px; border-radius: var(--radius-lg); border: 1px solid var(--line-2); background: rgba(17, 24, 35, 0.75); color: var(--text-2); }
  .nav:hover:not(:disabled) { color: var(--accent); border-color: var(--accent-line); }
  .nav:disabled { opacity: 0.3; }
  .book { position: relative; display: flex; padding: 14px; border-radius: 14px; background: linear-gradient(160deg, #3a2a1c, #22180f 50%, #2e2014); box-shadow: inset 0 0 0 2px rgba(245, 165, 36, 0.25), inset 0 0 0 6px #1a120b, inset 0 0 0 7px rgba(245, 165, 36, 0.15), 0 20px 50px rgba(0, 0, 0, 0.6); animation: turnpage 0.35s var(--ease); }
  @keyframes turnpage { from { opacity: 0; transform: translateX(calc(var(--dir) * 24px)); } }
  .page { position: relative; padding: 16px 18px 26px; background: linear-gradient(180deg, #151d29, #10161f); }
  .page.left { border-radius: 8px 2px 2px 8px; box-shadow: inset -14px 0 18px -12px rgba(0, 0, 0, 0.8); }
  .page.right { border-radius: 2px 8px 8px 2px; box-shadow: inset 14px 0 18px -12px rgba(0, 0, 0, 0.8); }
  .spine { position: absolute; left: 50%; top: 14px; bottom: 14px; width: 4px; margin-left: -2px; background: linear-gradient(90deg, rgba(0, 0, 0, 0.6), rgba(255, 255, 255, 0.06), rgba(0, 0, 0, 0.6)); }
  .grid { display: grid; grid-template-columns: repeat(3, 108px); grid-auto-rows: 148px; gap: 10px; }
  .pocket { position: relative; display: grid; place-items: center; padding: 0; border-radius: 8px; border: 1px dashed rgba(138, 154, 176, 0.25); background: rgba(10, 14, 20, 0.45); color: var(--faint); }
  .pocket.filled { border-style: solid; border-color: rgba(255, 255, 255, 0.06); }
  .pocket:hover { border-color: var(--line-3); }
  .pocket.sel { border: 2px solid var(--accent); box-shadow: 0 0 0 3px var(--accent-soft); }
  .pocket.target { border: 1px dashed var(--accent); background: rgba(245, 165, 36, 0.06); }
  .pn { font-size: 11px; opacity: 0.6; }
  .sleeve { position: absolute; inset: 0; border-radius: 8px; background: linear-gradient(125deg, rgba(255, 255, 255, 0.07), transparent 35%, transparent 65%, rgba(255, 255, 255, 0.04)); pointer-events: none; }
  .pnum { position: absolute; bottom: 7px; left: 0; right: 0; text-align: center; font-size: 10px; color: var(--faint); }

  .actions { display: flex; align-items: center; justify-content: center; gap: 8px; min-height: 40px; padding: 6px 12px; border-radius: var(--radius-lg); background: rgba(13, 18, 26, 0.85); border: 1px solid var(--line-2); font-size: 13px; }
  .pk { margin-right: 6px; }
  .tray { display: flex; flex-direction: column; gap: 8px; padding: 10px 14px; border-radius: var(--radius-lg); background: var(--card); border: 1px solid var(--line-2); }
  .cards { display: flex; gap: 10px; overflow-x: auto; overflow-y: hidden; padding: 6px 2px 8px; min-height: 140px; }
  .tc { padding: 0; border: 2px solid transparent; border-radius: 9px; background: none; transition: transform 0.15s var(--ease); }
  .tc:hover { transform: translateY(-4px); }
  .tc.sel { border-color: var(--accent); transform: translateY(-6px); box-shadow: 0 0 0 3px var(--accent-soft); }
  .tray .empty { flex: 1; flex-direction: row; padding: 10px; }
  .toast { position: absolute; left: 50%; top: 70px; transform: translateX(-50%); z-index: 40; display: flex; align-items: center; gap: 10px; padding: 10px 16px; border-radius: var(--radius); background: var(--panel-2); border: 1px solid var(--ok-line); color: var(--text); font-size: 13px; font-weight: 600; box-shadow: var(--shadow); white-space: nowrap; }
  .toast i { color: var(--ok); }
  .toast.err { border-color: var(--danger-line); }
  .toast.err i { color: var(--danger); }
</style>
