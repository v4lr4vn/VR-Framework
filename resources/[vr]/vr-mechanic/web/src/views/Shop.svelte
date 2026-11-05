<script>
  import { call, money, errorText } from '../lib/api.js';

  let { p, onclose } = $props();

  const ICON = { engine_parts: 'fa-gears', brake_pads: 'fa-circle-stop', clutch_kit: 'fa-gear', suspension_parts: 'fa-arrows-up-down', tyre_set: 'fa-life-ring', radiator_parts: 'fa-fan', body_panel: 'fa-car-burst', repair_kit: 'fa-toolbox' };

  let items = $state(p.items.map((i) => ({ ...i, qty: 1 })));
  let me = $state(p.me);
  let pay = $state('bank');
  let busy = $state(null);
  let toast = $state(null);
  let timer;

  let funds = $derived(pay === 'bank' ? me.bank : pay === 'cash' ? me.cash : me.company?.balance || 0);

  function say(text, kind = 'ok') {
    clearTimeout(timer);
    toast = { text, kind };
    timer = setTimeout(() => (toast = null), 2800);
  }

  async function buy(it) {
    if (busy) return;
    busy = it.item;
    const r = await call('shop.buy', { item: it.item, count: it.qty, payment: pay });
    busy = null;
    if (!r.ok) return say(errorText(r.error), 'err');
    it.have = r.data.have;
    if (r.data.me) me = r.data.me;
    say(`Bought ${r.data.count} × ${it.label} for ${money(r.data.total)}`);
    it.qty = 1;
  }
</script>

<section class="shop card" aria-label="Parts counter">
  <header>
    <span class="logo"><i class="fa-solid fa-boxes-stacked"></i></span>
    <div class="title">
      <h1>Parts counter</h1>
      <p class="sub">{p.workshop.label}</p>
    </div>
    <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
  </header>

  <div class="pay">
    <span class="label">Pay with</span>
    <div class="methods">
      <button class="m" class:on={pay === 'bank'} onclick={() => (pay = 'bank')}><i class="fa-solid fa-building-columns"></i>Bank<span class="num">{money(me.bank)}</span></button>
      <button class="m" class:on={pay === 'cash'} onclick={() => (pay = 'cash')}><i class="fa-solid fa-money-bill-wave"></i>Cash<span class="num">{money(me.cash)}</span></button>
      {#if me.company}
        <button class="m" class:on={pay === 'company'} onclick={() => (pay = 'company')}><i class="fa-solid fa-briefcase"></i>Company<span class="num">{money(me.company.balance)}</span></button>
      {/if}
    </div>
  </div>

  <div class="list scroll">
    {#each items as it (it.item)}
      <div class="row">
        <span class="pi"><i class="fa-solid {ICON[it.item] || 'fa-wrench'}"></i></span>
        <div class="pm">
          <span class="pn">{it.label}</span>
          <span class="hint">You have <span class="num">{it.have}</span></span>
        </div>
        <span class="num price">{money(it.price)}</span>
        <div class="qty">
          <button onclick={() => (it.qty = Math.max(1, it.qty - 1))} aria-label="Fewer"><i class="fa-solid fa-minus"></i></button>
          <span class="num">{it.qty}</span>
          <button onclick={() => (it.qty = Math.min(20, it.qty + 1))} aria-label="More"><i class="fa-solid fa-plus"></i></button>
        </div>
        <button class="btn small primary" disabled={busy !== null || funds < it.price * it.qty} onclick={() => buy(it)}>
          <i class="fa-solid fa-cart-plus"></i><span class="num">{money(it.price * it.qty)}</span>
        </button>
      </div>
    {/each}
  </div>

  {#if toast}
    <div class="toast {toast.kind}" role="status"><i class="fa-solid {toast.kind === 'err' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>{toast.text}</div>
  {/if}
</section>

<style>
  .shop { position: relative; width: 620px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 15px; }
  .title { flex: 1; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .pay { display: flex; flex-direction: column; gap: 8px; padding: 14px 16px 4px; }
  .methods { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
  .m { display: flex; flex-direction: column; align-items: flex-start; gap: 2px; padding: 8px 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 13px; font-weight: 600; text-align: left; }
  .m i { color: var(--muted); font-size: 12px; }
  .m .num { color: var(--muted); font-size: 11px; font-weight: 500; }
  .m.on { border-color: var(--accent); background: var(--accent-soft); color: var(--text); }
  .m.on i { color: var(--accent); }
  .list { padding: 12px 16px 16px; display: flex; flex-direction: column; gap: 6px; }
  .row { display: grid; grid-template-columns: 36px 1fr 70px 96px 108px; align-items: center; gap: 12px; padding: 8px 10px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); }
  .pi { width: 36px; height: 36px; border-radius: var(--radius); display: grid; place-items: center; background: var(--panel-2); color: var(--accent); font-size: 14px; }
  .pm { display: flex; flex-direction: column; gap: 1px; }
  .pn { font-size: 13px; font-weight: 700; }
  .price { color: var(--text-2); font-size: 13px; text-align: right; }
  .qty { display: grid; grid-template-columns: 28px 1fr 28px; align-items: center; height: 28px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--bg-2); overflow: hidden; }
  .qty button { height: 100%; border: 0; background: none; color: var(--muted); font-size: 10px; }
  .qty button:hover { color: var(--text); background: var(--panel-2); }
  .qty span { text-align: center; font-size: 13px; }
  .row .btn { width: 100%; }
  .toast { position: absolute; left: 50%; bottom: 16px; transform: translateX(-50%); z-index: 40; display: flex; align-items: center; gap: 10px; padding: 10px 16px; border-radius: var(--radius); background: var(--panel-2); border: 1px solid var(--ok-line); color: var(--text); font-size: 13px; font-weight: 600; box-shadow: var(--shadow); white-space: nowrap; }
  .toast i { color: var(--ok); }
  .toast.err { border-color: var(--danger-line); }
  .toast.err i { color: var(--danger); }
</style>
