<script>
  import { call, nui, money, same, hex, rgbOf, clone, errorText } from '../lib/api.js';
  import { untrack } from 'svelte';
  import Stepper from '../ui/Stepper.svelte';

  let { p, result, onclose } = $props();

  const ALL_TABS = [
    ['perf', 'Power', 'fa-gauge-high'],
    ['paint', 'Paint', 'fa-fill-drip'],
    ['wheels', 'Wheels', 'fa-circle-dot'],
    ['lights', 'Lights', 'fa-lightbulb'],
    ['body', 'Body', 'fa-car-side'],
    ['extras', 'Extras', 'fa-sliders'],
  ];
  const design = p.design === true;
  const TABS = design ? ALL_TABS.filter(([k]) => k !== 'perf') : ALL_TABS;
  const FINISH = [[0, 'Normal'], [1, 'Metallic'], [2, 'Pearl'], [3, 'Matte'], [4, 'Metal'], [5, 'Chrome']];
  const TINT = [[0, 'None'], [3, 'Light smoke'], [2, 'Dark smoke'], [1, 'Pure black'], [5, 'Limo'], [6, 'Green']];
  const PLATES = [[0, 'Blue on white'], [3, 'Blue on white 2'], [4, 'Blue on white 3'], [1, 'Yellow on black'], [2, 'Yellow on blue'], [5, 'North Yankton']];
  const NEONS = [[0, 'Left'], [1, 'Right'], [2, 'Front'], [3, 'Back']];
  const perfKeys = p.performance.map((x) => x.key);
  const bodyKeys = p.bodyMods.filter((b) => b.key !== 'modHorns').map((b) => b.key);
  const TAB_KEYS = {
    perf: perfKeys,
    paint: ['color1', 'color2', 'paintType1', 'paintType2', 'pearlescentColor'],
    wheels: ['wheels', 'modFrontWheels', 'modCustomTiresF', 'wheelColor'],
    lights: ['modXenon', 'xenonColor', 'neonEnabled', 'neonColor'],
    body: bodyKeys,
    extras: ['windowTint', 'plateIndex', 'modHorns', 'livery', 'modLivery'],
  };

  let tab = $state(design ? 'paint' : 'perf');
  let current = $state(clone(p.current));
  let cart = $state(p.cart ? clone(p.cart) : {});
  let quote = $state(null);
  let quoting = $state(false);
  let customers = $state(p.customers || []);
  let target = $state(p.customers?.[0] ? String(p.customers[0].id) : 'self');
  let method = $state('bank');
  let me = $state(p.me || { cash: 0, bank: 0 });
  let pending = $state(p.pending ? { amount: p.pending.amount, left: 0 } : null);
  let busy = $state(false);
  let err = $state('');
  let toast = $state(null);
  let slot = $state(1);
  let custom = $state('');
  let wheelType = $state(p.current.wheels ?? 0);
  let wheelList = $state([]);
  let timer, toastTimer, tick;

  const val = (k) => (k in cart ? cart[k] : current[k]);
  const changed = (k) => k in cart;
  const count = (t) => TAB_KEYS[t].filter((k) => k in cart).length;
  const nItems = $derived(Object.keys(cart).length);

  function set(k, v) {
    const next = { ...cart };
    if (same(v, current[k])) delete next[k];
    else next[k] = v;
    cart = next;
  }

  function say(text, kind = 'ok') {
    clearTimeout(toastTimer);
    toast = { text, kind };
    toastTimer = setTimeout(() => (toast = null), 3200);
  }

  $effect(() => {
    const c = $state.snapshot(cart);
    nui('tunePreview', { cart: c });
    clearTimeout(timer);
    err = '';
    if (!Object.keys(c).length) {
      quote = null;
      quoting = false;
      return;
    }
    quoting = true;
    timer = setTimeout(async () => {
      const r = await call(design ? 'design.quote' : 'tune.quote', { changes: c });
      quoting = false;
      quote = r.ok ? r.data : null;
      if (!r.ok) err = errorText(r.error);
    }, 320);
  });

  $effect(() => {
    nui('tuneWheels', { type: wheelType }).then((l) => (wheelList = Array.isArray(l) ? l : []));
  });

  $effect(() => {
    const r = result;
    if (!r) return;
    untrack(() => {
      pending = null;
      clearInterval(tick);
      if (r.accepted) {
        current = r.current ? clone(r.current) : { ...current, ...cart };
        say('Paid. Everything is fitted');
      } else say('Not paid. The changes were taken off', 'err');
      cart = {};
    });
  });

  function startCountdown(seconds) {
    clearInterval(tick);
    pending.left = seconds;
    tick = setInterval(() => {
      if (!pending) return clearInterval(tick);
      pending.left = Math.max(0, pending.left - 1);
    }, 1000);
  }

  async function refresh() {
    const r = await call('customers');
    if (r.ok) {
      customers = r.data;
      if (target !== 'self' && !customers.some((c) => String(c.id) === target)) target = customers[0] ? String(customers[0].id) : 'self';
    }
  }

  async function placeOrder() {
    if (busy || !nItems) return;
    busy = true;
    err = '';
    const r = await call('design.order', { changes: $state.snapshot(cart), label: p.label });
    busy = false;
    if (!r.ok) return (err = errorText(r.error));
    cart = {};
    say(`Order #${r.data.id} placed`);
  }

  async function send() {
    if (busy || !nItems) return;
    busy = true;
    err = '';
    const changes = $state.snapshot(cart);
    if (target === 'self') {
      const r = await call('tune.self', { changes, method });
      busy = false;
      if (!r.ok) return (err = errorText(r.error));
      cart = {};
      say(`Paid. Order #${r.data.orderId} is ready to fit`);
      return;
    }
    const r = await call('tune.bill', { changes, target: Number(target) });
    busy = false;
    if (!r.ok) return (err = errorText(r.error));
    pending = { amount: r.data.amount, left: r.data.seconds || 60 };
    startCountdown(r.data.seconds || 60);
  }

  function pickWheel(i) {
    if (wheelType === current.wheels && i === current.modFrontWheels) {
      const next = { ...cart };
      delete next.wheels;
      delete next.modFrontWheels;
      cart = next;
    } else cart = { ...cart, wheels: wheelType, modFrontWheels: i };
  }

  function pickPaint(rgb) {
    set(`color${slot}`, rgb);
  }

  function pickCustom() {
    const rgb = rgbOf(custom);
    if (rgb) pickPaint(rgb);
  }

  function toggleNeon(i) {
    const n = [...(val('neonEnabled') || [false, false, false, false])];
    n[i] = !n[i];
    set('neonEnabled', n);
  }

  function allNeon(on) {
    set('neonEnabled', [on, on, on, on]);
  }

  let paintKey = $derived(`color${slot}`);
  let paintNow = $derived(val(paintKey));
  let finishOk = $derived(slot === 1 || !!val('color2'));
  let neons = $derived(val('neonEnabled') || [false, false, false, false]);
  let wheelsNow = $derived(val('wheels'));
  let wheelNow = $derived(val('modFrontWheels'));
  let price = (k) => p.prices[k] || 0;
  let commission = $derived(quote ? Math.floor((quote.total * p.commission) / 100) : 0);
  let selfFunds = $derived(method === 'bank' ? me.bank : method === 'cash' ? me.cash : me.company?.balance || 0);
  let canSend = $derived(nItems > 0 && !!quote && !quoting && !pending && !busy && (target !== 'self' || selfFunds >= quote.total));
  let canOrder = $derived(nItems > 0 && !!quote && !quoting && !busy);

  let dragging = false;
  let lastMove = 0;
  const down = (e) => {
    if (e.button === 0) dragging = true;
  };
  const up = () => (dragging = false);
  const move = (e) => {
    if (!dragging) return;
    const t = performance.now();
    if (t - lastMove < 16) return;
    lastMove = t;
    nui('cam', { dx: e.movementX, dy: e.movementY });
  };
  const wheel = (e) => nui('cam', { dz: e.deltaY > 0 ? 0.5 : -0.5 });
</script>

<svelte:window onmouseup={up} />
<div class="drag" role="presentation" onmousedown={down} onmousemove={move} onwheel={wheel}></div>
<p class="drag-hint"><i class="fa-solid fa-hand"></i>Drag to look around, scroll to zoom</p>

<aside class="tune card" aria-label={design ? 'Design a new look' : 'Customise vehicle'}>
  <header>
    <span class="logo"><i class="fa-solid fa-paint-roller"></i></span>
    <div class="title">
      <h1>{p.label || 'Vehicle'}</h1>
      <p class="sub">{design ? `Design a new look · ${p.workshop.label}` : p.workshop.label}</p>
    </div>
    {#if p.plate}<span class="plate num">{p.plate}</span>{/if}
    <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
  </header>

  <nav class="tabs6" style="--n:{TABS.length}">
    {#each TABS as [k, label, ic]}
      <button class="t" class:on={tab === k} onclick={() => (tab = k)}>
        <i class="fa-solid {ic}"></i><span>{label}</span>
        {#if count(k)}<span class="dot num">{count(k)}</span>{/if}
      </button>
    {/each}
  </nav>

  {#if !p.preview}
    <div class="notice warn slim"><i class="fa-solid fa-eye-slash"></i><span>Someone has control of this vehicle, so changes may not show until they are paid for.</span></div>
  {/if}

  <div class="content scroll">
    {#if tab === 'perf'}
      {#each p.performance as perf (perf.key)}
        {#if perf.toggle}
          <div class="group">
            <div class="gh"><span>{perf.label}</span><span class="num price">{money(perf.price)}</span></div>
            <div class="chips">
              <button class="pill" class:on={!val(perf.key)} onclick={() => set(perf.key, false)}>Off{#if !current[perf.key]}<i class="fa-solid fa-check fit"></i>{/if}</button>
              <button class="pill" class:on={!!val(perf.key)} onclick={() => set(perf.key, true)}>Fitted{#if current[perf.key]}<i class="fa-solid fa-check fit"></i>{/if}</button>
            </div>
          </div>
        {:else}
          {@const n = Math.min(p.options.perf[perf.key] || 0, perf.levels.length - 1)}
          {#if n > 0}
            <div class="group">
              <div class="gh"><span>{perf.label}</span>{#if changed(perf.key)}<span class="chip accent">Changed</span>{/if}</div>
              <div class="levels" style="--n:{n + 1}">
                {#each Array(n + 1) as _, i}
                  {@const lvl = i - 1}
                  <button class="lv" class:on={val(perf.key) === lvl} class:fitted={current[perf.key] === lvl} onclick={() => set(perf.key, lvl)}>
                    <span class="ln">{lvl < 0 ? 'Stock' : `Level ${lvl + 1}`}</span>
                    <span class="lp num">{lvl < 0 ? 'Free' : money(perf.levels[i])}</span>
                    <span class="seg">{#each Array(n) as _, s}<span class:f={s <= lvl}></span>{/each}</span>
                  </button>
                {/each}
              </div>
            </div>
          {/if}
        {/if}
      {/each}
    {:else if tab === 'paint'}
      <div class="seg2">
        <button class:on={slot === 1} onclick={() => (slot = 1)}><span class="sw-mini" style="background:{hex(val('color1'))}"></span>Primary</button>
        <button class:on={slot === 2} onclick={() => (slot = 2)}><span class="sw-mini" style="background:{val('color2') ? hex(val('color2')) : 'var(--panel-3)'}"></span>Secondary</button>
      </div>
      <div class="group">
        <div class="gh"><span>Colour</span><span class="num price">{money(price('paint'))}</span></div>
        <div class="swatches">
          {#each p.swatches as s}
            <button class="sw" class:on={same(paintNow, s.rgb)} style="--c:{hex(s.rgb)}" title={s.label} aria-label={s.label} onclick={() => pickPaint(s.rgb)}></button>
          {/each}
        </div>
        <div class="customrow">
          <span class="sw-mini big" style="background:{paintNow ? hex(paintNow) : 'var(--panel-3)'}"></span>
          <input class="input mono" maxlength="7" placeholder={paintNow ? hex(paintNow).toUpperCase() : '#RRGGBB'} bind:value={custom} onkeydown={(e) => e.key === 'Enter' && pickCustom()} />
          <button class="btn small" disabled={!rgbOf(custom)} onclick={pickCustom}>Use colour</button>
        </div>
      </div>
      <div class="group">
        <div class="gh"><span>Finish</span><span class="num price">{money(price('paintType'))}</span></div>
        <div class="chips">
          {#each FINISH as [id, label]}
            <button class="pill" disabled={!finishOk} class:on={val(`paintType${slot}`) === id} onclick={() => set(`paintType${slot}`, id)}>{label}{#if current[`paintType${slot}`] === id}<i class="fa-solid fa-check fit"></i>{/if}</button>
          {/each}
        </div>
        {#if !finishOk}<p class="hint">Pick a secondary colour first.</p>{/if}
      </div>
      {#if slot === 1}
        <div class="group">
          <div class="gh"><span>Pearlescent</span><span class="num price">{money(price('pearl'))}</span></div>
          <div class="swatches">
            {#each p.palette as c}
              <button class="sw" class:on={val('pearlescentColor') === c.id} style="--c:{c.hex}" title={c.label} aria-label={c.label} onclick={() => set('pearlescentColor', c.id)}></button>
            {/each}
          </div>
        </div>
      {/if}
    {:else if tab === 'wheels'}
      <div class="group">
        <div class="gh"><span>Style</span><span class="num price">{money(price('wheels'))}</span></div>
        <div class="chips">
          {#each p.options.wheelTypes as [id, label]}
            <button class="pill" class:on={wheelType === id} onclick={() => (wheelType = id)}>{label}{#if wheelsNow === id && wheelNow >= 0}<i class="fa-solid fa-circle fit sm"></i>{/if}</button>
          {/each}
        </div>
      </div>
      <div class="wheels">
        <button class="wh" class:on={wheelsNow === wheelType && wheelNow === -1} onclick={() => pickWheel(-1)}><i class="fa-solid fa-circle-dot"></i>Stock wheels</button>
        {#each wheelList as name, i}
          <button class="wh" class:on={wheelsNow === wheelType && wheelNow === i} class:fitted={current.wheels === wheelType && current.modFrontWheels === i} onclick={() => pickWheel(i)}>
            <i class="fa-solid fa-circle-notch"></i><span>{name}</span>
          </button>
        {/each}
      </div>
      <div class="group">
        <div class="gh"><span>Custom tyres</span></div>
        <div class="chips">
          <button class="pill" class:on={!val('modCustomTiresF')} onclick={() => set('modCustomTiresF', false)}>Standard</button>
          <button class="pill" class:on={!!val('modCustomTiresF')} onclick={() => set('modCustomTiresF', true)}>Custom</button>
        </div>
      </div>
      <div class="group">
        <div class="gh"><span>Wheel colour</span><span class="num price">{money(price('wheelColor'))}</span></div>
        <div class="swatches">
          {#each p.palette as c}
            <button class="sw" class:on={val('wheelColor') === c.id} style="--c:{c.hex}" title={c.label} aria-label={c.label} onclick={() => set('wheelColor', c.id)}></button>
          {/each}
        </div>
      </div>
    {:else if tab === 'lights'}
      <div class="group">
        <div class="gh"><span>Xenon headlights</span><span class="num price">{money(price('xenon'))}</span></div>
        <div class="chips">
          <button class="pill" class:on={!val('modXenon')} onclick={() => set('modXenon', false)}>Halogen</button>
          <button class="pill" class:on={!!val('modXenon')} onclick={() => set('modXenon', true)}>Xenon</button>
        </div>
      </div>
      {#if val('modXenon')}
        <div class="group">
          <div class="gh"><span>Xenon colour</span><span class="num price">{money(price('xenonColor'))}</span></div>
          <div class="swatches">
            {#each p.xenonColors as c}
              <button class="sw glow" class:on={val('xenonColor') === c.id} style="--c:{c.hex}" title={c.label} aria-label={c.label} onclick={() => set('xenonColor', c.id)}></button>
            {/each}
          </div>
        </div>
      {/if}
      {#if p.options.neon}
        <div class="group">
          <div class="gh"><span>Neon kit</span><span class="num price">{money(price('neon'))}</span></div>
          <div class="neon">
            {#each NEONS as [i, label]}
              <button class="pill" class:on={neons[i]} onclick={() => toggleNeon(i)}>{label}</button>
            {/each}
            <button class="pill" onclick={() => allNeon(!neons.every(Boolean))}>{neons.every(Boolean) ? 'None' : 'All'}</button>
          </div>
        </div>
        <div class="group">
          <div class="gh"><span>Neon colour</span><span class="num price">{money(price('neonColor'))}</span></div>
          <div class="swatches">
            {#each p.neonColors as c}
              <button class="sw glow" class:on={same(val('neonColor'), c.rgb)} style="--c:{hex(c.rgb)}" title={c.label} aria-label={c.label} onclick={() => set('neonColor', c.rgb)}></button>
            {/each}
          </div>
        </div>
      {/if}
    {:else if tab === 'body'}
      <div class="gh pad"><span>Body parts</span><span class="num price">{money(price('body'))} each</span></div>
      <div class="list">
        {#each p.bodyMods as b (b.key)}
          {#if b.key !== 'modHorns' && p.options.body[b.key]}
            <Stepper label={b.label} options={p.options.body[b.key]} value={val(b.key)} fitted={current[b.key]} onchange={(n) => set(b.key, n)} />
          {/if}
        {/each}
        {#if !bodyKeys.some((k) => p.options.body[k])}<div class="empty"><i class="fa-solid fa-car-side"></i>No body parts for this vehicle</div>{/if}
      </div>
    {:else if tab === 'extras'}
      <div class="group">
        <div class="gh"><span>Window tint</span><span class="num price">{money(price('windowTint'))}</span></div>
        <div class="chips">
          {#each TINT as [id, label]}
            <button class="pill" class:on={val('windowTint') === id || (id === 0 && val('windowTint') === -1)} onclick={() => set('windowTint', id)}>{label}</button>
          {/each}
        </div>
      </div>
      <div class="group">
        <div class="gh"><span>Plate</span><span class="num price">{money(price('plateIndex'))}</span></div>
        <div class="chips">
          {#each PLATES as [id, label]}
            <button class="pill" class:on={val('plateIndex') === id} onclick={() => set('plateIndex', id)}>{label}</button>
          {/each}
        </div>
      </div>
      <div class="list">
        {#if p.options.body.modHorns}
          <Stepper label="Horn" options={p.options.body.modHorns} value={val('modHorns')} fitted={current.modHorns} onchange={(n) => set('modHorns', n)} />
        {/if}
        {#if p.options.livery}
          <Stepper label="Livery" options={p.options.livery.options} value={val(p.options.livery.key)} fitted={current[p.options.livery.key]} stock="None" onchange={(n) => set(p.options.livery.key, n)} />
        {/if}
      </div>
    {/if}
  </div>

  <footer class="cart">
    {#if design}
      <div class="ch">
        <span class="label">Your order</span>
        <span class="hint">{nItems ? `${quote?.items.length ?? '…'} item${quote?.items.length === 1 ? '' : 's'}` : 'Pick what you want changed'}</span>
        {#if nItems}<button class="link" onclick={() => (cart = {})}><i class="fa-solid fa-rotate-left"></i>Undo all</button>{/if}
      </div>
      {#if quote && quote.items.length}
        <div class="items scroll">
          {#each quote.items as it}
            <div class="it"><span>{it.label}</span><span class="num">{money(it.price)}</span></div>
          {/each}
        </div>
      {/if}
      <div class="total">
        <span>Estimated total</span>
        <span class="num">{quoting ? '…' : money(quote?.total || 0)}</span>
      </div>
      <p class="hint">You get an order sheet to hand to a mechanic. You pay when they start the work.</p>
      {#if err}<div class="notice danger slim"><i class="fa-solid fa-circle-exclamation"></i><span>{err}</span></div>{/if}
      <button class="btn primary go" disabled={!canOrder} onclick={placeOrder}><i class="fa-solid fa-clipboard-check"></i>Place order</button>
    {:else if pending}
      <div class="wait">
        <span class="spin"><i class="fa-solid fa-hourglass-half"></i></span>
        <div><strong>Waiting for the customer</strong><p class="hint">Bill of <span class="num">{money(pending.amount)}</span> sent{pending.left ? ` · ${pending.left}s left` : ''}</p></div>
      </div>
    {:else}
      <div class="ch">
        <span class="label">Order</span>
        <span class="hint">{nItems ? `${quote?.items.length ?? '…'} item${quote?.items.length === 1 ? '' : 's'}` : 'Nothing picked yet'}</span>
        {#if nItems}<button class="link" onclick={() => (cart = {})}><i class="fa-solid fa-rotate-left"></i>Undo all</button>{/if}
      </div>
      {#if quote && quote.items.length}
        <div class="items scroll">
          {#each quote.items as it}
            <div class="it"><span>{it.label}</span><span class="num">{money(it.price)}</span></div>
          {/each}
        </div>
      {/if}
      <div class="total">
        <span>Total</span>
        <span class="num">{quoting ? '…' : money(quote?.total || 0)}</span>
      </div>
      <div class="who">
        <select class="input" bind:value={target} aria-label="Who pays">
          {#each customers as c}
            <option value={String(c.id)}>Customer #{c.id} · {c.distance} m away</option>
          {/each}
          <option value="self">I'll pay myself</option>
        </select>
        <button class="btn icon" onclick={refresh} aria-label="Find nearby customers"><i class="fa-solid fa-arrows-rotate"></i></button>
      </div>
      {#if target === 'self'}
        <div class="methods">
          <button class="m" class:on={method === 'bank'} onclick={() => (method = 'bank')}><i class="fa-solid fa-building-columns"></i>Bank<span class="num">{money(me.bank)}</span></button>
          <button class="m" class:on={method === 'cash'} onclick={() => (method = 'cash')}><i class="fa-solid fa-money-bill-wave"></i>Cash<span class="num">{money(me.cash)}</span></button>
          {#if me.company}
            <button class="m" class:on={method === 'company'} onclick={() => (method = 'company')}><i class="fa-solid fa-briefcase"></i>Company<span class="num">{money(me.company.balance)}</span></button>
          {/if}
        </div>
      {:else if quote}
        <p class="hint">The customer pays when they accept. You earn <span class="num">{money(commission)}</span> ({p.commission}%).</p>
      {/if}
      {#if err}<div class="notice danger slim"><i class="fa-solid fa-circle-exclamation"></i><span>{err}</span></div>{/if}
      <button class="btn primary go" disabled={!canSend} onclick={send}>
        {#if target === 'self'}<i class="fa-solid fa-wrench"></i>Pay and fit{:else}<i class="fa-solid fa-file-invoice-dollar"></i>Send bill{/if}
        {#if quote}<span class="num">{money(quote.total)}</span>{/if}
      </button>
    {/if}
  </footer>

  {#if toast}
    <div class="toast {toast.kind}" role="status"><i class="fa-solid {toast.kind === 'err' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>{toast.text}</div>
  {/if}
</aside>

<style>
  .drag { position: fixed; inset: 0; cursor: grab; }
  .drag:active { cursor: grabbing; }
  .drag-hint { position: fixed; left: 24px; bottom: 22px; display: flex; align-items: center; gap: 8px; padding: 7px 12px; border-radius: 999px; background: rgba(10, 14, 20, 0.7); border: 1px solid var(--line-2); color: var(--text-2); font-size: 12px; font-weight: 600; pointer-events: none; }
  .drag-hint i { color: var(--accent); }
  .tune { position: relative; z-index: 1; width: 470px; max-width: calc(100vw - 40px); height: 100%; display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 10px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 36px; height: 36px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 14px; }
  .title { flex: 1; min-width: 0; }
  h1 { font-size: 16px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sub { color: var(--muted); font-size: 12px; }
  .plate { padding: 3px 8px; border-radius: 4px; background: #e9eef4; color: #18212d; font-size: 12px; font-weight: 600; letter-spacing: 0.1em; border: 2px solid #9fb0c4; }
  .x { width: 32px; height: 32px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .tabs6 { display: grid; grid-template-columns: repeat(var(--n), 1fr); border-bottom: 1px solid var(--line-2); }
  .t { position: relative; display: flex; flex-direction: column; align-items: center; gap: 4px; padding: 9px 0 8px; background: none; border: 0; border-bottom: 2px solid transparent; color: var(--muted); font-size: 11px; font-weight: 600; margin-bottom: -1px; }
  .t i { font-size: 14px; }
  .t:hover { color: var(--text); }
  .t.on { color: var(--text); border-bottom-color: var(--accent); }
  .t.on i { color: var(--accent); }
  .t .dot { position: absolute; top: 5px; right: 14px; min-width: 15px; height: 15px; padding: 0 4px; border-radius: 8px; background: var(--accent); color: var(--accent-ink); font-size: 9px; line-height: 15px; }
  .slim { margin: 10px 14px 0; padding: 8px 10px; }
  .content { flex: 1; min-height: 0; padding: 14px; display: flex; flex-direction: column; gap: 14px; }
  .group { display: flex; flex-direction: column; gap: 8px; }
  .gh { display: flex; align-items: center; justify-content: space-between; gap: 8px; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; color: var(--text-2); }
  .gh.pad { padding-bottom: 2px; }
  .price { color: var(--accent-2); font-weight: 500; letter-spacing: 0; text-transform: none; font-size: 12px; }
  .gh .chip { height: 18px; font-size: 10px; letter-spacing: 0.04em; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .pill { display: inline-flex; align-items: center; gap: 6px; height: 30px; padding: 0 12px; border-radius: 999px; border: 1px solid var(--line-3); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; }
  .pill:hover:not(:disabled) { color: var(--text); border-color: var(--accent-line); }
  .pill:disabled { opacity: 0.4; }
  .pill.on { background: var(--accent-soft); border-color: var(--accent); color: var(--accent-2); }
  .fit { font-size: 9px; color: var(--ok); }
  .fit.sm { font-size: 6px; }
  .levels { display: grid; grid-template-columns: repeat(var(--n), 1fr); gap: 6px; }
  .lv { display: flex; flex-direction: column; align-items: flex-start; gap: 3px; padding: 8px 9px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: inherit; text-align: left; min-width: 0; }
  .lv:hover { border-color: var(--line-3); background: var(--panel-2); }
  .lv.on { border-color: var(--accent); background: var(--accent-soft); }
  .lv.fitted:not(.on) { border-style: dashed; border-color: var(--ok-line); }
  .ln { font-size: 12px; font-weight: 700; }
  .lp { font-size: 11px; color: var(--muted); }
  .lv.on .lp { color: var(--accent-2); }
  .seg { display: flex; gap: 2px; width: 100%; margin-top: 3px; }
  .seg span { flex: 1; height: 3px; border-radius: 2px; background: var(--line-3); }
  .seg span.f { background: var(--accent); }
  .seg2 { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; padding: 3px; border-radius: var(--radius-lg); background: var(--bg-2); border: 1px solid var(--line-2); }
  .seg2 button { display: flex; align-items: center; justify-content: center; gap: 8px; height: 32px; border-radius: var(--radius); border: 0; background: none; color: var(--muted); font-size: 13px; font-weight: 600; }
  .seg2 button.on { background: var(--panel-2); color: var(--text); box-shadow: inset 0 0 0 1px var(--line-3); }
  .sw-mini { width: 14px; height: 14px; border-radius: 50%; border: 1px solid rgba(255, 255, 255, 0.25); }
  .sw-mini.big { width: 34px; height: 34px; border-radius: var(--radius); flex: none; }
  .swatches { display: grid; grid-template-columns: repeat(11, 1fr); gap: 7px; }
  .sw { aspect-ratio: 1; border-radius: 50%; border: 2px solid var(--line-3); background: var(--c); padding: 0; }
  .sw:hover { transform: scale(1.08); }
  .sw.on { border-color: var(--accent); box-shadow: 0 0 0 2px var(--bg), 0 0 0 4px var(--accent); }
  .sw.glow { box-shadow: 0 0 8px color-mix(in srgb, var(--c) 55%, transparent); }
  .sw.glow.on { box-shadow: 0 0 0 2px var(--bg), 0 0 0 4px var(--accent), 0 0 10px var(--c); }
  .customrow { display: flex; gap: 8px; align-items: center; }
  .customrow .input { height: 32px; font-size: 13px; text-transform: uppercase; }
  .wheels { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
  .wh { display: flex; align-items: center; gap: 8px; height: 34px; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; text-align: left; min-width: 0; }
  .wh span { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .wh i { color: var(--faint); font-size: 11px; }
  .wh:hover { border-color: var(--line-3); color: var(--text); }
  .wh.on { border-color: var(--accent); background: var(--accent-soft); color: var(--accent-2); }
  .wh.on i { color: var(--accent); }
  .wh.fitted:not(.on) { border-style: dashed; border-color: var(--ok-line); }
  .neon { display: grid; grid-template-columns: repeat(5, 1fr); gap: 6px; }
  .neon .pill { justify-content: center; padding: 0 6px; }
  .list { display: flex; flex-direction: column; gap: 6px; }
  .cart { border-top: 1px solid var(--line-2); padding: 12px 14px 14px; display: flex; flex-direction: column; gap: 9px; background: rgba(13, 18, 26, 0.75); }
  .ch { display: flex; align-items: center; gap: 8px; }
  .ch .hint { flex: 1; }
  .link { display: inline-flex; align-items: center; gap: 6px; background: none; border: 0; color: var(--muted); font-size: 12px; font-weight: 600; padding: 0; }
  .link:hover { color: var(--danger-text); }
  .items { max-height: 104px; display: flex; flex-direction: column; gap: 3px; padding-right: 4px; }
  .it { display: flex; justify-content: space-between; font-size: 12px; color: var(--text-2); }
  .it .num { color: var(--muted); }
  .total { display: flex; justify-content: space-between; align-items: baseline; padding-top: 8px; border-top: 1px dashed var(--line-3); font-size: 13px; color: var(--text-2); font-weight: 600; }
  .total .num { font-size: 22px; color: var(--accent-2); }
  .who { display: flex; gap: 6px; }
  .who .input { height: 34px; font-size: 13px; }
  .methods { display: grid; grid-template-columns: repeat(auto-fit, minmax(90px, 1fr)); gap: 6px; }
  .m { display: flex; flex-direction: column; align-items: flex-start; gap: 2px; padding: 7px 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; text-align: left; }
  .m i { color: var(--muted); font-size: 11px; }
  .m .num { color: var(--muted); font-size: 11px; font-weight: 500; }
  .m.on { border-color: var(--accent); background: var(--accent-soft); color: var(--text); }
  .m.on i { color: var(--accent); }
  .cart .notice.slim { margin: 0; }
  .go { height: 40px; font-size: 14px; }
  .go .num { margin-left: 4px; opacity: 0.8; }
  .wait { display: flex; align-items: center; gap: 12px; padding: 10px 2px; }
  .wait strong { font-size: 14px; }
  .spin { width: 36px; height: 36px; border-radius: 50%; display: grid; place-items: center; background: var(--accent-soft); color: var(--accent); border: 1px solid var(--accent-line); animation: pulse 1.4s var(--ease) infinite; }
  @keyframes pulse { 50% { box-shadow: 0 0 0 6px var(--accent-soft); } }
  .toast { position: absolute; left: 50%; bottom: 18px; transform: translateX(-50%); z-index: 40; display: flex; align-items: center; gap: 10px; padding: 10px 16px; border-radius: var(--radius); background: var(--panel-2); border: 1px solid var(--ok-line); color: var(--text); font-size: 13px; font-weight: 600; box-shadow: var(--shadow); white-space: nowrap; }
  .toast i { color: var(--ok); }
  .toast.err { border-color: var(--danger-line); }
  .toast.err i { color: var(--danger); }
</style>
