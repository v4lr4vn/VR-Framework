<script>
  import Card from '../ui/Card.svelte';
  import Slab from '../ui/Slab.svelte';
  import PackArt from '../ui/PackArt.svelte';
  import Viewer from './Viewer.svelte';
  import { call, money, errorText } from '../lib/api.js';
  import { sfx } from '../lib/sfx.js';

  let { p, onclose } = $props();

  let s = $state(p);
  let tab = $state('packs');
  let method = $state(p.me.bank >= 750 ? 'bank' : 'cash');
  let qty = $state({});
  let sel = $state([]);
  let gsel = $state([]);
  let tier = $state(p.grading.tiers[0]?.id);
  let busy = $state(false);
  let toast = $state(null);
  let viewing = $state(null);
  let reveal = $state(null);
  let now = $state(Date.now());
  let timer;

  $effect(() => {
    const id = setInterval(() => (now = Date.now()), 1000);
    return () => clearInterval(id);
  });

  const opened = Date.now();
  let meta = $derived(s.meta);
  let funds = $derived(method === 'bank' ? s.me.bank : s.me.cash);
  let sellTotal = $derived(s.hand.filter((c) => sel.includes(c.uid)).reduce((t, c) => t + (c.price || 0), 0));
  let ungraded = $derived(s.hand.filter((c) => !c.grade));
  let tierDef = $derived(s.grading.tiers.find((t) => t.id === tier));
  let fee = $derived((tierDef?.fee || 0) * gsel.length);
  let ready = $derived(s.grading.submissions.filter((x) => x.ready || x.readyIn - (now - opened) / 1000 <= 0).length);

  function say(text, kind = 'ok') {
    clearTimeout(timer);
    toast = { text, kind };
    timer = setTimeout(() => (toast = null), 3000);
  }

  async function run(action, data) {
    if (busy) return null;
    busy = true;
    const r = await call(action, { ...data, method });
    busy = false;
    if (!r.ok) {
      say(errorText(r.error), 'err');
      return null;
    }
    if (r.data?.shop) {
      s = r.data.shop;
      sel = sel.filter((u) => s.hand.some((c) => c.uid === u));
      gsel = gsel.filter((u) => s.hand.some((c) => c.uid === u && !c.grade));
    }
    return r.data;
  }

  async function buyPack(pk) {
    const n = qty[pk.id] || 1;
    const r = await run('shop.pack', { pack: pk.id, count: n });
    if (!r) return;
    sfx.coin();
    say(`${n} × ${pk.label} in your pockets. Use them from your inventory to open.`);
  }

  async function buyBinder() {
    const r = await run('shop.binder', {});
    if (!r) return;
    sfx.coin();
    say('Binder bought. Use it from your inventory.');
  }

  async function sell() {
    const r = await run('shop.sell', { uids: sel });
    if (!r) return;
    sfx.coin();
    sel = [];
    say(`Sold ${r.sold} card${r.sold === 1 ? '' : 's'} for ${money(r.total)}`);
  }

  async function grade() {
    const r = await run('shop.grade', { uids: gsel, tier });
    if (!r) return;
    gsel = [];
    say(`${r.submitted} card${r.submitted === 1 ? '' : 's'} sent to the grader. Back in ${r.minutes} minutes.`);
  }

  async function collect() {
    const r = await run('shop.collect', {});
    if (!r) return;
    if (r.graded?.length) {
      reveal = r.graded;
      const top = Math.max(...r.graded.map((c) => c.grade || 0));
      sfx.reveal(top >= 10 ? 'legendary' : top >= 9 ? 'epic' : top >= 7 ? 'rare' : 'uncommon', top >= 10 ? 'holo' : 'none');
    } else say(`${r.given} card${r.given === 1 ? '' : 's'} collected`);
  }

  function key(e) {
    if (e.key === 'Escape' && reveal) reveal = null;
  }

  const toggle = (list, uid, max = 999) => (list.includes(uid) ? list.filter((u) => u !== uid) : list.length >= max ? list : [...list, uid]);
  const left = (x) => {
    const sec = Math.max(0, Math.ceil(x.readyIn - (now - opened) / 1000));
    return sec <= 0 ? 'Ready' : sec >= 60 ? `${Math.ceil(sec / 60)} min` : `${sec}s`;
  };
</script>

<svelte:window onkeydown={key} />

<div class="room">
  <section class="shop card" aria-label="Card shop">
    <header>
      <span class="logo"><i class="fa-solid fa-layer-group"></i></span>
      <div class="title"><h1>{s.label}</h1><p class="sub">Packs, binders, buy-backs and grading by {meta.companyName}</p></div>
      <div class="pay">
        <button class="m" class:on={method === 'bank'} onclick={() => (method = 'bank')}><i class="fa-solid fa-building-columns"></i><span class="num">{money(s.me.bank)}</span></button>
        <button class="m" class:on={method === 'cash'} onclick={() => (method = 'cash')}><i class="fa-solid fa-money-bill-wave"></i><span class="num">{money(s.me.cash)}</span></button>
      </div>
      <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
    </header>

    <nav class="tabs">
      <button class="tab" class:on={tab === 'packs'} onclick={() => (tab = 'packs')}><i class="fa-solid fa-box-open"></i>Packs</button>
      {#if s.sell}<button class="tab" class:on={tab === 'sell'} onclick={() => (tab = 'sell')}><i class="fa-solid fa-hand-holding-dollar"></i>Sell cards <span class="count">{s.hand.length}</span></button>{/if}
      <button class="tab" class:on={tab === 'grading'} onclick={() => (tab = 'grading')}><i class="fa-solid fa-award"></i>Grading {#if ready}<span class="chip ok">{ready} ready</span>{/if}</button>
      <button class="tab" class:on={tab === 'binders'} onclick={() => (tab = 'binders')}><i class="fa-solid fa-book"></i>Binders</button>
    </nav>

    <div class="body scroll">
      {#if tab === 'packs'}
        {#if s.unclaimed}
          <div class="notice warn"><i class="fa-solid fa-inbox"></i><span>{s.unclaimed} card{s.unclaimed === 1 ? ' is' : 's are'} waiting for you here because your pockets were full.</span><button class="btn small" disabled={busy} onclick={collect}>Collect</button></div>
        {/if}
        <div class="packs">
          {#each s.packs as pk (pk.id)}
            <div class="prod">
              <PackArt pack={pk} w={150} />
              <div class="pi">
                <span class="label">{pk.set} · {pk.cards} cards</span>
                <h2>{pk.label}</h2>
                <p class="hint">Every pack has at least one Rare or better. Foils can show up at any rarity.</p>
                <div class="buy">
                  <div class="qty">
                    <button onclick={() => (qty[pk.id] = Math.max(1, (qty[pk.id] || 1) - 1))} aria-label="Fewer"><i class="fa-solid fa-minus"></i></button>
                    <span class="num">{qty[pk.id] || 1}</span>
                    <button onclick={() => (qty[pk.id] = Math.min(10, (qty[pk.id] || 1) + 1))} aria-label="More"><i class="fa-solid fa-plus"></i></button>
                  </div>
                  <button class="btn primary" disabled={busy || funds < pk.price * (qty[pk.id] || 1)} onclick={() => buyPack(pk)}><i class="fa-solid fa-cart-shopping"></i>Buy <span class="num">{money(pk.price * (qty[pk.id] || 1))}</span></button>
                </div>
              </div>
            </div>
          {/each}
        </div>
      {:else if tab === 'sell'}
        {#if s.hand.length}
          <div class="grid">
            {#each s.hand as c (c.uid)}
              <button class="pick" class:on={sel.includes(c.uid)} onclick={() => (sel = toggle(sel, c.uid, 25))} oncontextmenu={(e) => { e.preventDefault(); viewing = c; }}>
                <Card {c} {meta} w={124} />
                <span class="price num">{money(c.price)}</span>
                {#if sel.includes(c.uid)}<span class="tick"><i class="fa-solid fa-check"></i></span>{/if}
              </button>
            {/each}
          </div>
        {:else}
          <div class="empty"><i class="fa-solid fa-hand"></i>You have no cards on you</div>
        {/if}
      {:else if tab === 'grading'}
        <div class="gcols">
          <div class="gl">
            <span class="label">Send cards in</span>
            {#if ungraded.length}
              <div class="grid small">
                {#each ungraded as c (c.uid)}
                  <button class="pick" class:on={gsel.includes(c.uid)} onclick={() => (gsel = toggle(gsel, c.uid, s.grading.max))}>
                    <Card {c} {meta} w={104} />
                    {#if gsel.includes(c.uid)}<span class="tick"><i class="fa-solid fa-check"></i></span>{/if}
                  </button>
                {/each}
              </div>
            {:else}
              <div class="empty"><i class="fa-solid fa-award"></i>No ungraded cards on you</div>
            {/if}
          </div>
          <div class="gr">
            <div class="box">
              <div class="box-head"><h3>Service</h3><span class="hint">Up to {s.grading.max} cards</span></div>
              <div class="box-body tiers">
                {#each s.grading.tiers as t (t.id)}
                  <button class="tier" class:on={tier === t.id} onclick={() => (tier = t.id)}>
                    <b>{t.label}</b>
                    <span class="hint">{t.minutes} minutes</span>
                    <span class="num">{money(t.fee)} per card</span>
                  </button>
                {/each}
                <div class="feerow"><span>{gsel.length} card{gsel.length === 1 ? '' : 's'}</span><span class="num">{money(fee)}</span></div>
                <button class="btn primary" disabled={busy || !gsel.length || funds < fee} onclick={grade}><i class="fa-solid fa-paper-plane"></i>Send for grading</button>
              </div>
            </div>
            <div class="box">
              <div class="box-head"><h3>At the grader</h3><button class="btn small" disabled={busy || !ready} onclick={collect}><i class="fa-solid fa-box-archive"></i>Collect</button></div>
              <div class="box-body subs">
                {#each s.grading.submissions as x (x.id)}
                  <div class="sub-row">
                    <Card c={x.card} {meta} w={48} />
                    <div class="sm"><b>{x.card.name}</b><span class="hint">{s.grading.tiers.find((t) => t.id === x.tier)?.label}</span></div>
                    <span class="chip" class:ok={left(x) === 'Ready'}>{left(x)}</span>
                  </div>
                {/each}
                {#if !s.grading.submissions.length}<p class="hint">Nothing at the grader.</p>{/if}
              </div>
            </div>
          </div>
        </div>
      {:else if tab === 'binders'}
        <div class="prod">
          <div class="bookart"><i class="fa-solid fa-book"></i><span>VALRAVN</span></div>
          <div class="pi">
            <span class="label">{s.binder.capacity} pockets</span>
            <h2>Card binder</h2>
            <p class="hint">Keep your collection safe and show it off. Use it from your inventory to open it. Whoever holds the binder holds every card in it, so you can trade a whole collection at once.</p>
            <div class="buy"><button class="btn primary" disabled={busy || funds < s.binder.price} onclick={buyBinder}><i class="fa-solid fa-cart-shopping"></i>Buy <span class="num">{money(s.binder.price)}</span></button></div>
          </div>
        </div>
      {/if}
    </div>

    {#if tab === 'sell' && s.hand.length}
      <footer>
        <span class="hint">Right-click a card to inspect it</span>
        <span class="grow"></span>
        <button class="btn ghost small" onclick={() => (sel = sel.length ? [] : s.hand.slice(0, 25).map((c) => c.uid))}>{sel.length ? 'Clear' : 'Select all'}</button>
        <button class="btn primary" disabled={busy || !sel.length} onclick={sell}><i class="fa-solid fa-hand-holding-dollar"></i>Sell {sel.length || ''} for <span class="num">{money(sellTotal)}</span></button>
      </footer>
    {/if}

    {#if toast}<div class="toast {toast.kind}" role="status"><i class="fa-solid {toast.kind === 'err' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>{toast.text}</div>{/if}
  </section>
</div>

{#if viewing}<Viewer c={viewing} {meta} onclose={() => (viewing = null)} />{/if}

{#if reveal}
  <div class="reveal" role="dialog" aria-modal="true" aria-label="Graded cards">
    <div class="scrim" role="presentation" onclick={() => (reveal = null)}></div>
    <div class="rv">
      <h2>Back from {meta.companyName}</h2>
      <div class="slabs">
        {#each reveal as c, i (c.uid)}
          <div class="sl" style="--i:{i}"><Slab {c} {meta} w={180} /></div>
        {/each}
      </div>
      <button class="btn primary" onclick={() => (reveal = null)}>Nice</button>
    </div>
  </div>
{/if}

<style>
  .room { position: fixed; inset: 0; display: grid; place-items: center; background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.35), rgba(10, 14, 20, 0.7)); }
  .shop { position: relative; width: 1040px; height: 680px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 15px; }
  .title { flex: 1; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .pay { display: flex; gap: 6px; }
  .m { display: inline-flex; align-items: center; gap: 8px; height: 32px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 12px; }
  .m.on { border-color: var(--accent); background: var(--accent-soft); color: var(--text); }
  .m.on i { color: var(--accent); }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .tabs { padding: 0 12px; }
  .tab .chip { height: 18px; font-size: 10px; }
  .body { flex: 1; min-height: 0; padding: 16px; display: flex; flex-direction: column; gap: 14px; }
  .packs { display: flex; flex-direction: column; gap: 12px; }
  .prod { display: flex; gap: 24px; align-items: center; padding: 18px 22px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .pi { flex: 1; display: flex; flex-direction: column; gap: 6px; }
  h2 { font-size: 22px; font-weight: 700; }
  .buy { display: flex; gap: 10px; align-items: center; margin-top: 8px; }
  .buy .btn { height: 38px; }
  .qty { display: grid; grid-template-columns: 32px 40px 32px; align-items: center; height: 38px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--bg-2); overflow: hidden; }
  .qty button { height: 100%; border: 0; background: none; color: var(--muted); }
  .qty button:hover { color: var(--text); background: var(--panel-2); }
  .qty span { text-align: center; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(132px, 1fr)); gap: 14px; }
  .grid.small { grid-template-columns: repeat(auto-fill, minmax(112px, 1fr)); gap: 10px; }
  .pick { position: relative; display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 6px; border-radius: 12px; border: 2px solid transparent; background: none; color: inherit; }
  .pick:hover { background: rgba(255, 255, 255, 0.03); }
  .pick.on { border-color: var(--accent); background: var(--accent-soft); }
  .price { font-size: 13px; color: var(--accent-2); }
  .tick { position: absolute; top: 2px; right: 2px; width: 24px; height: 24px; border-radius: 50%; display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 12px; box-shadow: 0 2px 6px rgba(0, 0, 0, 0.5); }
  .gcols { display: grid; grid-template-columns: 1fr 320px; gap: 16px; min-height: 0; }
  .gl { display: flex; flex-direction: column; gap: 10px; }
  .gr { display: flex; flex-direction: column; gap: 12px; }
  .tiers { display: flex; flex-direction: column; gap: 8px; }
  .tier { display: grid; grid-template-columns: 1fr auto; grid-template-rows: auto auto; text-align: left; gap: 2px 10px; padding: 10px 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text-2); }
  .tier .num { grid-row: span 2; align-self: center; font-size: 12px; }
  .tier.on { border-color: var(--accent); background: var(--accent-soft); color: var(--text); }
  .feerow { display: flex; justify-content: space-between; padding-top: 6px; border-top: 1px dashed var(--line-3); font-size: 13px; color: var(--text-2); }
  .subs { display: flex; flex-direction: column; gap: 8px; max-height: 210px; overflow-y: auto; }
  .sub-row { display: grid; grid-template-columns: 48px 1fr auto; align-items: center; gap: 10px; }
  .sm { display: flex; flex-direction: column; font-size: 13px; min-width: 0; }
  .sm b { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .bookart { width: 150px; height: 190px; border-radius: 10px 14px 14px 10px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 10px; background: linear-gradient(160deg, #3a2a1c, #22180f 60%, #2e2014); box-shadow: inset 6px 0 0 #1a120b, inset 0 0 0 2px rgba(245, 165, 36, 0.3), 0 12px 30px rgba(0, 0, 0, 0.5); color: #ffc85c; font-size: 34px; }
  .bookart span { font-size: 13px; letter-spacing: 0.25em; font-weight: 700; }
  footer { display: flex; align-items: center; gap: 10px; padding: 12px 16px; border-top: 1px solid var(--line-2); }
  .grow { flex: 1; }
  .notice .btn { margin-left: auto; }
  .toast { position: absolute; left: 50%; bottom: 18px; transform: translateX(-50%); z-index: 40; display: flex; align-items: center; gap: 10px; padding: 10px 16px; border-radius: var(--radius); background: var(--panel-2); border: 1px solid var(--ok-line); color: var(--text); font-size: 13px; font-weight: 600; box-shadow: var(--shadow); white-space: nowrap; }
  .toast i { color: var(--ok); }
  .toast.err { border-color: var(--danger-line); }
  .toast.err i { color: var(--danger); }
  .reveal { position: fixed; inset: 0; z-index: 30; display: grid; place-items: center; }
  .reveal .scrim { position: absolute; inset: 0; background: radial-gradient(ellipse at center, rgba(26, 36, 51, 0.9), rgba(6, 9, 13, 0.96)); }
  .rv { position: relative; display: flex; flex-direction: column; align-items: center; gap: 24px; }
  .rv h2 { text-transform: uppercase; letter-spacing: 0.06em; font-size: 18px; color: var(--accent-2); }
  .slabs { display: flex; gap: 24px; flex-wrap: wrap; justify-content: center; max-width: calc(100vw - 60px); }
  .sl { animation: drop 0.6s cubic-bezier(0.2, 1.2, 0.4, 1) backwards; animation-delay: calc(var(--i) * 0.25s); }
  @keyframes drop { from { transform: translateY(-60px) scale(0.9); opacity: 0; } }
</style>
