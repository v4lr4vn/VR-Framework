<script>
  import Modal from '../ui/Modal.svelte';
  import { call, money, errorText, reasonText } from '../lib/api.js';

  let { p, vehicle, color, onclose, say } = $props();

  const lo = Math.floor(vehicle.price * (1 - p.me.discount / 100));
  const hi = Math.floor(vehicle.price * (1 + p.me.maxMarkup / 100));
  let customers = $state(null);
  let target = $state(null);
  let price = $state(vehicle.price);
  let payment = $state('full');
  let down = $state(Math.ceil(vehicle.price * 0.1));
  let term = $state(12);
  let check = $state(null);
  let busy = $state(false);
  let err = $state('');
  let sent = $state(false);

  async function loadCustomers() {
    const r = await call('customers');
    customers = r.ok ? r.data : [];
    if (customers.length && !customers.find((c) => c.id === target)) target = customers[0].id;
  }

  $effect(() => {
    loadCustomers();
  });

  let pct = $derived(Math.round(((price - vehicle.price) / vehicle.price) * 1000) / 10);
  let commission = $derived(Math.floor((price * p.me.commission) / 100));

  async function checkFinance() {
    if (!target) return;
    const r = await call('quote', { model: vehicle.model, target, price, down: Math.floor(down), term });
    check = r.ok ? r.data : { approved: false, reasons: [r.error] };
    if (r.ok && r.data.down) down = r.data.down;
  }

  async function send() {
    if (busy || !target) return;
    busy = true;
    err = '';
    const r = await call('offer', { target, model: vehicle.model, price: Math.floor(price), payment, down: Math.floor(down), term, color });
    busy = false;
    if (!r.ok) {
      err = r.error === 'bad_price' && r.data ? `Price must be between ${money(r.data.min)} and ${money(r.data.max)}` : errorText(r.error);
      return;
    }
    sent = true;
    say(payment === 'finance' && r.data.finance === false ? 'Offer sent, but the bank would decline their finance' : 'Offer sent. Waiting for the customer.');
    onclose();
  }
</script>

<Modal title="Sell the {vehicle.brand} {vehicle.name}" icon="fa-handshake" {onclose} width={520}>
  <div class="field">
    <span>Customer <button class="link" onclick={loadCustomers}><i class="fa-solid fa-rotate"></i>Refresh</button></span>
    {#if customers === null}
      <p class="hint">Looking around…</p>
    {:else if !customers.length}
      <div class="notice warn"><i class="fa-solid fa-user-slash"></i><span>Nobody is close enough. Stand next to your customer on the sales floor.</span></div>
    {:else}
      <div class="people">
        {#each customers as c}
          <button class="person" class:on={target === c.id} onclick={() => { target = c.id; check = null; }}>
            <i class="fa-solid fa-user"></i><span>Customer <span class="num">#{c.id}</span></span><span class="num muted">{c.distance}m</span>
          </button>
        {/each}
      </div>
    {/if}
  </div>

  <label class="field">
    <span>Price <em class="num {pct < 0 ? 'off' : pct > 0 ? 'up' : ''}">{pct > 0 ? '+' : ''}{pct}% of list</em></span>
    <input class="input num big" type="number" min={lo} max={hi} bind:value={price} />
    <input type="range" min={lo} max={hi} step="100" bind:value={price} />
    <span class="range num"><span>{money(lo)}</span><span>List {money(vehicle.price)}</span><span>{money(hi)}</span></span>
  </label>

  <div class="field">
    <span>Payment</span>
    <div class="terms">
      <button class="pill" class:on={payment === 'full'} onclick={() => (payment = 'full')}>Pays in full</button>
      {#if p.finance.enabled}<button class="pill" class:on={payment === 'finance'} onclick={() => { payment = 'finance'; check = null; }}>Bank finance</button>{/if}
    </div>
  </div>

  {#if payment === 'finance'}
    <div class="fin">
      <label class="field"><span>Down payment <em class="num">{money(down)}</em></span><input type="range" min={Math.ceil(price * 0.1)} max={price} step="100" bind:value={down} /></label>
      <div class="terms">{#each [4, 8, 12, 24] as t}<button class="pill" class:on={term === t} onclick={() => { term = t; check = null; }}>{t} payments</button>{/each}</div>
      <button class="btn small" disabled={!target} onclick={checkFinance}><i class="fa-solid fa-magnifying-glass-dollar"></i>Check with the bank</button>
      {#if check}
        {#if check.approved}
          <div class="notice ok"><i class="fa-solid fa-circle-check"></i><span>Approved: {check.term} payments of {money(check.installment)} after {money(check.down)} down.</span></div>
        {:else}
          <div class="notice danger"><i class="fa-solid fa-circle-xmark"></i><span>{(check.reasons || []).map(reasonText).join('. ')}</span></div>
        {/if}
      {/if}
    </div>
  {/if}

  <div class="sum"><span>Your commission</span><span class="num">{money(commission)}</span></div>
  {#if err}<div class="notice danger"><i class="fa-solid fa-circle-exclamation"></i><span>{err}</span></div>{/if}
  <div class="row">
    <button class="btn ghost" onclick={onclose}>Cancel</button>
    <button class="btn primary" disabled={busy || !target || sent} onclick={send}><i class="fa-solid fa-paper-plane"></i>Send offer</button>
  </div>
</Modal>

<style>
  .link { margin-left: 8px; border: 0; background: none; color: var(--accent); font-size: 12px; display: inline-flex; gap: 5px; align-items: center; }
  .people { display: flex; flex-direction: column; gap: 6px; }
  .person { display: grid; grid-template-columns: 18px 1fr auto; gap: 10px; align-items: center; height: 38px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 13px; text-align: left; }
  .person i { color: var(--muted); }
  .person.on { border-color: var(--accent); background: var(--accent-soft); color: var(--text); }
  .field em { font-style: normal; margin-left: 6px; color: var(--muted); }
  .field em.off { color: var(--ok-text); }
  .field em.up { color: var(--accent-2); }
  .big { height: 42px; font-size: 18px; }
  input[type='range'] { width: 100%; accent-color: var(--accent); }
  .range { display: flex; justify-content: space-between; font-size: 11px; color: var(--faint); }
  .terms { display: flex; gap: 6px; flex-wrap: wrap; }
  .pill { height: 28px; padding: 0 12px; border-radius: 999px; border: 1px solid var(--line-3); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; }
  .pill.on { background: var(--accent-soft); border-color: var(--accent); color: var(--accent-2); }
  .fin { display: flex; flex-direction: column; gap: 10px; }
  .sum { display: flex; justify-content: space-between; align-items: baseline; padding-top: 10px; border-top: 1px solid var(--line-2); font-size: 14px; color: var(--text-2); }
  .sum .num { font-size: 20px; font-weight: 600; color: var(--ok-text); }
  .row { display: flex; justify-content: flex-end; gap: 8px; }
</style>
