<script>
  import { call, stats as loadStats, nui, money, errorText } from '../lib/api.js';
  import BuyModal from './BuyModal.svelte';
  import SellModal from './SellModal.svelte';
  import Modal from '../ui/Modal.svelte';

  let { p, onclose } = $props();

  let cat = $state('all');
  let search = $state('');
  let sort = $state('price');
  let sel = $state(p.catalogue[0]?.model ?? null);
  let color = $state(p.colors[0]?.id ?? 0);
  let st = $state({});
  let preview = $state(false);
  let buying = $state(false);
  let selling = $state(false);
  let placing = $state(false);
  let busy = $state(false);
  let toast = $state(null);
  let dragging = false;
  let lastX = 0;

  const ICON = { motorcycles: 'fa-motorcycle', boats: 'fa-ship', helicopters: 'fa-helicopter', planes: 'fa-plane', cycles: 'fa-bicycle', vans: 'fa-van-shuttle', commercial: 'fa-truck', industrial: 'fa-truck-monster', offroad: 'fa-truck-pickup', suvs: 'fa-car-rear' };
  const icon = (c) => ICON[c] || 'fa-car-side';

  let counts = $derived.by(() => {
    const c = {};
    for (const v of p.catalogue) c[v.category] = (c[v.category] || 0) + 1;
    return c;
  });
  let cats = $derived(Object.keys(counts).sort((a, b) => (p.categories[a] || a).localeCompare(p.categories[b] || b)));
  let list = $derived.by(() => {
    let l = p.catalogue;
    if (cat !== 'all') l = l.filter((v) => v.category === cat);
    const s = search.trim().toLowerCase();
    if (s) l = l.filter((v) => `${v.brand} ${v.name} ${v.model}`.toLowerCase().includes(s));
    l = [...l];
    if (sort === 'price') l.sort((a, b) => a.price - b.price);
    else if (sort === 'priceDesc') l.sort((a, b) => b.price - a.price);
    else l.sort((a, b) => `${a.brand} ${a.name}`.localeCompare(`${b.brand} ${b.name}`));
    return l;
  });
  let v = $derived(p.catalogue.find((x) => x.model === sel));
  let price = $derived(v ? Math.floor(v.price * (1 + (p.selfService.markup || 0) / 100)) : 0);
  let max = $derived.by(() => {
    const m = { speed: 1, accel: 0.01, braking: 0.01, traction: 0.01 };
    for (const s of Object.values(st)) for (const k of Object.keys(m)) m[k] = Math.max(m[k], s[k] || 0);
    return m;
  });
  let canBuy = $derived(p.selfService.open);

  $effect(() => {
    loadStats(p.catalogue.map((x) => x.model)).then((r) => (st = r || {}));
  });

  let timer;
  function say(text, kind = 'ok') {
    clearTimeout(timer);
    toast = { text, kind };
    timer = setTimeout(() => (toast = null), 3400);
  }

  async function startPreview() {
    const r = await nui('preview', { model: sel, color });
    if (r === false) return say('This vehicle cannot be previewed here', 'err');
    preview = true;
  }

  function endPreview() {
    nui('previewEnd');
    preview = false;
  }

  function pickColor(id) {
    color = id;
    if (preview) nui('previewColor', { color: id });
  }

  async function testDrive() {
    if (busy) return;
    busy = true;
    const r = await call('testdrive', { model: sel });
    busy = false;
    if (!r.ok) return say(r.error === 'cooldown' && r.data ? `Next test drive in ${r.data.seconds}s` : errorText(r.error), 'err');
    preview = false;
  }

  async function setDisplay(slot) {
    const r = await call('display.set', { slot, model: sel });
    if (!r.ok) return say(errorText(r.error), 'err');
    p.display[slot - 1] = sel;
    placing = false;
    say(`Spot ${slot} now shows the ${v.brand} ${v.name}`);
  }

  const down = (e) => { dragging = true; lastX = e.clientX; };
  const move = (e) => {
    if (!dragging) return;
    const dx = e.clientX - lastX;
    if (Math.abs(dx) < 3) return;
    lastX = e.clientX;
    nui('previewRotate', { dx: dx * 0.6 });
  };
  const up = () => (dragging = false);
  const wheel = (e) => nui('previewRotate', { dz: e.deltaY > 0 ? 0.6 : -0.6 });

  const mph = (ms) => Math.round((ms || 0) * 2.236936);
  const pctOf = (n, m) => Math.max(4, Math.min(100, Math.round(((n || 0) / m) * 100)));
</script>

<svelte:window onmouseup={up} />

{#if preview && v}
  <div class="drag" role="presentation" onmousedown={down} onmousemove={move} onwheel={wheel}></div>
  <div class="pbar card">
    <div class="pinfo">
      <span class="brand">{v.brand}</span>
      <strong>{v.name}</strong>
      <span class="num price">{money(p.me.staff ? v.price : price)}</span>
    </div>
    <div class="swatches">
      {#each p.colors as c}
        <button class="sw" class:on={color === c.id} style="--c:{c.hex}" title={c.label} onclick={() => pickColor(c.id)} aria-label={c.label}></button>
      {/each}
    </div>
    <div class="pact">
      <button class="btn icon" onclick={() => nui('previewRotate', { dx: -30 })} aria-label="Rotate left"><i class="fa-solid fa-rotate-left"></i></button>
      <button class="btn icon" onclick={() => nui('previewRotate', { dx: 30 })} aria-label="Rotate right"><i class="fa-solid fa-rotate-right"></i></button>
      <button class="btn" disabled={busy} onclick={testDrive}><i class="fa-solid fa-flag-checkered"></i>Test drive</button>
      {#if p.me.staff}
        <button class="btn primary" onclick={() => { endPreview(); selling = true; }}><i class="fa-solid fa-handshake"></i>Sell</button>
      {:else}
        <button class="btn primary" disabled={!canBuy && !p.me.boss} onclick={() => { endPreview(); buying = true; }}><i class="fa-solid fa-cart-shopping"></i>Buy</button>
      {/if}
      <button class="btn ghost" onclick={endPreview}><i class="fa-solid fa-arrow-left"></i>Showroom</button>
    </div>
    <p class="hint drag-hint">Drag to turn the car, scroll to zoom</p>
  </div>
{:else}
  <div class="dim"></div>
  <section class="shell card" aria-label="Dealership">
    <header class="top">
      <span class="logo"><i class="fa-solid fa-car-side"></i></span>
      <div class="title">
        <h1>{p.dealer.label}</h1>
        <p class="sub">{p.me.staff ? `Sales tablet · up to ${p.me.discount}% off · ${p.me.commission}% commission` : p.selfService.open ? 'Self-service showroom' : 'Sales staff are on the floor'}</p>
      </div>
      {#if !p.me.staff && !p.selfService.open}
        <span class="chip info"><i class="fa-solid fa-user-tie"></i>{p.selfService.staffOnDuty} salesperson{p.selfService.staffOnDuty === 1 ? '' : 's'} on duty</span>
      {/if}
      <span class="chip"><i class="fa-solid fa-building-columns"></i><span class="num">{money(p.me.bank)}</span></span>
      <span class="chip"><i class="fa-solid fa-money-bill-wave"></i><span class="num">{money(p.me.cash)}</span></span>
      <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
    </header>

    <div class="body">
      <nav class="cats scroll">
        <button class="cat" class:on={cat === 'all'} onclick={() => (cat = 'all')}><i class="fa-solid fa-layer-group"></i><span>All vehicles</span><span class="num count">{p.catalogue.length}</span></button>
        {#each cats as c}
          <button class="cat" class:on={cat === c} onclick={() => (cat = c)}><i class="fa-solid {icon(c)}"></i><span>{p.categories[c] || c}</span><span class="num count">{counts[c]}</span></button>
        {/each}
      </nav>

      <div class="mid">
        <div class="tools">
          <div class="search"><i class="fa-solid fa-magnifying-glass"></i><input class="input" placeholder="Search make or model" bind:value={search} /></div>
          <select class="input sort" bind:value={sort}>
            <option value="price">Cheapest first</option>
            <option value="priceDesc">Most expensive first</option>
            <option value="name">By name</option>
          </select>
        </div>
        <div class="grid scroll">
          {#each list as x (x.model)}
            <button class="tile" class:on={sel === x.model} onclick={() => (sel = x.model)}>
              <span class="ti"><i class="fa-solid {icon(x.category)}"></i></span>
              <span class="tb">{x.brand}</span>
              <span class="tn">{x.name}</span>
              <span class="tp num">{money(p.me.staff ? x.price : Math.floor(x.price * (1 + (p.selfService.markup || 0) / 100)))}</span>
              {#if st[x.model]}
                <span class="mini"><span style="width:{pctOf(st[x.model].speed, max.speed)}%"></span></span>
              {/if}
            </button>
          {/each}
          {#if !list.length}<div class="empty"><i class="fa-solid fa-magnifying-glass"></i>No vehicles match</div>{/if}
        </div>
      </div>

      <aside class="detail">
        {#if v}
          <span class="label">{p.categories[v.category] || v.category}</span>
          <h2>{v.brand} {v.name}</h2>
          <div class="bigprice num">{money(p.me.staff ? v.price : price)}</div>
          {#if p.me.staff}<p class="hint">List price. You can go down to {money(Math.floor(v.price * (1 - p.me.discount / 100)))} or up to {money(Math.floor(v.price * (1 + p.me.maxMarkup / 100)))}.</p>{/if}

          <div class="stats">
            {#if st[v.model]}
              {#each [['Top speed', `${mph(st[v.model].speed)} mph`, pctOf(st[v.model].speed, max.speed)], ['Acceleration', null, pctOf(st[v.model].accel, max.accel)], ['Braking', null, pctOf(st[v.model].braking, max.braking)], ['Handling', null, pctOf(st[v.model].traction, max.traction)]] as [k, val, n]}
                <div class="srow"><span class="sk">{k}</span><div class="bar"><span style="width:{n}%"></span></div><span class="sv num">{val ?? `${n}`}</span></div>
              {/each}
              <div class="srow"><span class="sk">Seats</span><span class="seats">{#each Array(Math.min(8, st[v.model].seats || 0)) as _}<i class="fa-solid fa-user"></i>{/each}</span></div>
            {/if}
          </div>

          <span class="label">Colour</span>
          <div class="swatches">
            {#each p.colors as c}
              <button class="sw" class:on={color === c.id} style="--c:{c.hex}" title={c.label} onclick={() => pickColor(c.id)} aria-label={c.label}></button>
            {/each}
          </div>

          <div class="actions">
            <button class="btn" onclick={startPreview}><i class="fa-solid fa-eye"></i>Preview</button>
            <button class="btn" disabled={busy} onclick={testDrive}><i class="fa-solid fa-flag-checkered"></i>Test drive</button>
            {#if p.me.staff}
              <button class="btn primary wide" onclick={() => (selling = true)}><i class="fa-solid fa-handshake"></i>Sell to a customer</button>
              {#if p.display}
                <button class="btn ghost wide" onclick={() => (placing = true)}><i class="fa-solid fa-star"></i>Put on display</button>
              {/if}
            {:else}
              <button class="btn primary wide" disabled={!canBuy && !p.me.boss} onclick={() => (buying = true)}><i class="fa-solid fa-cart-shopping"></i>{canBuy ? 'Buy now' : 'Buy for the company'}</button>
              {#if !canBuy}<p class="hint">A salesperson is working. Talk to them to buy this car, they may give you a better price.</p>{/if}
            {/if}
          </div>
        {/if}
      </aside>
    </div>

    {#if toast}
      <div class="toast {toast.kind}" role="status"><i class="fa-solid {toast.kind === 'err' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>{toast.text}</div>
    {/if}
  </section>
{/if}

{#if buying && v}
  <BuyModal {p} vehicle={v} {price} {color} onclose={() => (buying = false)} {say} />
{/if}
{#if selling && v}
  <SellModal {p} vehicle={v} {color} onclose={() => (selling = false)} {say} />
{/if}
{#if placing && v}
  <Modal title="Put on display" icon="fa-star" onclose={() => (placing = false)} width={420}>
    <p class="hint">Pick the showroom spot for the {v.brand} {v.name}.</p>
    <div class="slots">
      {#each p.display as m, i}
        <button class="slot" onclick={() => setDisplay(i + 1)}><span class="num">#{i + 1}</span><span>{p.catalogue.find((x) => x.model === m)?.name || m}</span></button>
      {/each}
    </div>
  </Modal>
{/if}

<style>
  .dim { position: fixed; inset: 0; background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.35), rgba(10, 14, 20, 0.65)); }
  .shell { position: relative; width: 1260px; height: 740px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  .top { display: flex; align-items: center; gap: 10px; padding: 14px 18px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 16px; }
  .title { flex: 1; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .top .chip { height: 26px; font-size: 12px; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); margin-left: 4px; }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .body { flex: 1; display: grid; grid-template-columns: 210px 1fr 380px; min-height: 0; }
  .cats { padding: 10px 8px; border-right: 1px solid var(--line-2); background: rgba(13, 18, 26, 0.55); display: flex; flex-direction: column; gap: 2px; }
  .cat { display: grid; grid-template-columns: 18px 1fr auto; align-items: center; gap: 10px; height: 34px; padding: 0 10px; border-radius: var(--radius); border: 1px solid transparent; background: none; color: var(--text-2); font-size: 13px; font-weight: 600; text-align: left; }
  .cat i { color: var(--muted); font-size: 12px; }
  .cat .count { font-size: 11px; color: var(--faint); font-weight: 500; }
  .cat:hover { background: var(--panel); color: var(--text); }
  .cat.on { background: var(--panel-2); border-color: var(--line-3); color: var(--text); }
  .cat.on i { color: var(--accent); }
  .mid { display: flex; flex-direction: column; min-height: 0; padding: 12px 14px; gap: 10px; }
  .tools { display: flex; gap: 8px; }
  .search { position: relative; flex: 1; }
  .search i { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--faint); font-size: 12px; }
  .search .input { padding-left: 32px; height: 34px; font-size: 13px; }
  .sort { width: 190px; height: 34px; font-size: 13px; }
  .grid { flex: 1; min-height: 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(170px, 1fr)); grid-auto-rows: 116px; gap: 8px; align-content: start; }
  .tile { position: relative; display: flex; flex-direction: column; align-items: flex-start; gap: 1px; padding: 12px; border-radius: var(--radius-lg); border: 1px solid var(--line-2); background: var(--panel); color: inherit; text-align: left; overflow: hidden; }
  .tile:hover { border-color: var(--line-3); background: var(--panel-2); }
  .tile.on { border-color: var(--accent); background: var(--accent-soft); box-shadow: inset 0 0 0 1px var(--accent); }
  .ti { position: absolute; right: 12px; top: 10px; color: var(--line-3); font-size: 26px; }
  .tile.on .ti { color: var(--accent-line); }
  .tb { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.06em; font-weight: 600; }
  .tn { font-size: 15px; font-weight: 700; }
  .tp { margin-top: auto; font-size: 14px; font-weight: 600; color: var(--accent-2); }
  .mini { width: 100%; height: 3px; border-radius: 2px; background: var(--line-2); margin-top: 6px; overflow: hidden; }
  .mini span { display: block; height: 100%; background: var(--info); }
  .detail { border-left: 1px solid var(--line-2); padding: 18px; display: flex; flex-direction: column; gap: 10px; overflow: auto; }
  h2 { font-size: 24px; font-weight: 700; line-height: 1.15; }
  .bigprice { font-size: 30px; font-weight: 600; color: var(--accent-2); }
  .stats { display: flex; flex-direction: column; gap: 8px; padding: 12px; border-radius: var(--radius-lg); background: var(--bg-2); border: 1px solid var(--line-2); margin: 4px 0; }
  .srow { display: grid; grid-template-columns: 96px 1fr 70px; align-items: center; gap: 10px; font-size: 12px; }
  .sk { color: var(--text-2); font-weight: 600; }
  .sv { text-align: right; color: var(--muted); }
  .seats { display: flex; gap: 4px; color: var(--info); font-size: 11px; }
  .swatches { display: flex; flex-wrap: wrap; gap: 6px; }
  .sw { width: 26px; height: 26px; border-radius: 50%; border: 2px solid var(--line-3); background: var(--c); padding: 0; }
  .sw.on { border-color: var(--accent); box-shadow: 0 0 0 2px var(--bg), 0 0 0 4px var(--accent); }
  .actions { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: auto; padding-top: 8px; }
  .actions .wide { grid-column: span 2; height: 40px; }
  .actions .hint { grid-column: span 2; }
  .slots { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
  .slot { display: flex; gap: 10px; align-items: center; height: 38px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 13px; text-align: left; }
  .slot:hover { border-color: var(--accent); color: var(--text); }
  .slot .num { color: var(--accent-2); }
  .drag { position: fixed; inset: 0; cursor: grab; }
  .pbar { position: fixed; left: 50%; bottom: 28px; transform: translateX(-50%); display: flex; flex-direction: column; align-items: center; gap: 12px; padding: 14px 18px; min-width: 760px; }
  .pinfo { display: flex; align-items: baseline; gap: 10px; }
  .pinfo .brand { color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: 0.08em; font-weight: 600; }
  .pinfo strong { font-size: 20px; }
  .pinfo .price { font-size: 18px; color: var(--accent-2); font-weight: 600; }
  .pact { display: flex; gap: 8px; }
  .drag-hint { font-size: 11px; }
  .toast { position: absolute; left: 50%; bottom: 18px; transform: translateX(-50%); z-index: 40; display: flex; align-items: center; gap: 10px; padding: 10px 16px; border-radius: var(--radius); background: var(--panel-2); border: 1px solid var(--ok-line); color: var(--text); font-size: 13px; font-weight: 600; box-shadow: var(--shadow); }
  .toast i { color: var(--ok); }
  .toast.err { border-color: var(--danger-line); }
  .toast.err i { color: var(--danger); }
</style>
