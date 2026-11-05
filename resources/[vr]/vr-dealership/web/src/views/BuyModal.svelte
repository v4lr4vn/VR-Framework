<script>
  import Modal from '../ui/Modal.svelte';
  import { call, money, errorText, reasonText } from '../lib/api.js';

  let { p, vehicle, price, color, onclose, say } = $props();

  const canSelf = p.selfService.open;
  let method = $state(canSelf ? 'bank' : 'society');
  let down = $state(Math.ceil(price * 0.1));
  let term = $state(12);
  let quote = $state(null);
  let quoting = $state(false);
  let busy = $state(false);
  let err = $state('');
  let timer;

  const terms = [4, 8, 12, 24];
  let fleetPrice = $derived(vehicle.price);
  let total = $derived(method === 'society' ? fleetPrice : price);

  $effect(() => {
    if (method !== 'finance') return;
    const d = { model: vehicle.model, down: Math.floor(down), term };
    clearTimeout(timer);
    quoting = true;
    timer = setTimeout(async () => {
      const r = await call('quote', d);
      quoting = false;
      if (r.ok) {
        quote = r.data;
        if (r.data.down !== Math.floor(down)) down = r.data.down;
      } else quote = null;
    }, 350);
  });

  async function confirm() {
    if (busy) return;
    busy = true;
    err = '';
    const r = await call('buy', { model: vehicle.model, color, payment: method, down: Math.floor(down), term });
    busy = false;
    if (!r.ok) {
      err = errorText(r.error);
      return;
    }
    say(r.data.delivered ? `It's yours! ${r.data.plate} is waiting outside.` : `It's yours! Collect ${r.data.plate} from the garage.`);
    onclose();
  }

  const methods = $derived([
    ...(canSelf ? [['bank', 'Bank', 'fa-building-columns', money(p.me.bank)], ['cash', 'Cash', 'fa-money-bill-wave', money(p.me.cash)]] : []),
    ...(canSelf && p.finance.enabled ? [['finance', 'Finance', 'fa-file-signature', 'Over time']] : []),
    ...(p.me.boss ? [['society', p.me.boss.label || 'Company', 'fa-briefcase', money(p.me.boss.balance)]] : []),
  ]);
</script>

<Modal title="Buy {vehicle.brand} {vehicle.name}" icon="fa-cart-shopping" {onclose} width={500}>
  <div class="methods">
    {#each methods as [k, label, ic, sub]}
      <button class="m" class:on={method === k} onclick={() => (method = k)}>
        <i class="fa-solid {ic}"></i><span>{label}</span><span class="num sub">{sub}</span>
      </button>
    {/each}
  </div>

  {#if method === 'finance'}
    <div class="fin">
      <label class="field">
        <span>Down payment <em class="num">{money(down)}</em></span>
        <input type="range" min={Math.ceil(price * 0.1)} max={price} step={Math.max(100, Math.round(price / 200))} bind:value={down} />
      </label>
      <div class="field">
        <span>Pay back over</span>
        <div class="terms">{#each terms as t}<button class="pill" class:on={term === t} onclick={() => (term = t)}>{t} payments</button>{/each}</div>
      </div>
      {#if quote}
        <div class="quote" class:no={!quote.approved}>
          <div class="q"><span>Financed</span><span class="num">{money(quote.financed)}</span></div>
          <div class="q"><span>Rate ({quote.tier?.label} credit)</span><span class="num">{quote.rate}%</span></div>
          <div class="q big"><span>{quote.term} payments of</span><span class="num">{money(quote.installment)}</span></div>
          <div class="q"><span>Total paid</span><span class="num">{money(quote.total + quote.down)}</span></div>
        </div>
        {#if quote.approved}
          <div class="notice ok"><i class="fa-solid fa-circle-check"></i><span>Approved. The car is the bank's collateral: if the finance goes to collections it can be repossessed.</span></div>
        {:else}
          <div class="notice danger"><i class="fa-solid fa-circle-xmark"></i><span>{quote.reasons.map(reasonText).join('. ')}</span></div>
        {/if}
      {:else if quoting}
        <p class="hint">Checking with the bank…</p>
      {/if}
    </div>
  {:else if method === 'society'}
    <div class="notice"><i class="fa-solid fa-briefcase"></i><span>Paid from the company account and added to the company fleet. Members can use it from fleet garages.</span></div>
  {/if}

  <div class="sum">
    <span>{method === 'finance' ? 'Due today' : 'Total'}</span>
    <span class="num">{money(method === 'finance' ? down : total)}</span>
  </div>
  {#if err}<div class="notice danger"><i class="fa-solid fa-circle-exclamation"></i><span>{err}</span></div>{/if}
  <div class="row">
    <button class="btn ghost" onclick={onclose}>Cancel</button>
    <button class="btn primary" disabled={busy || (method === 'finance' && (!quote || !quote.approved || quoting))} onclick={confirm}>
      <i class="fa-solid fa-key"></i>{method === 'finance' ? 'Sign and drive away' : 'Pay and drive away'}
    </button>
  </div>
</Modal>

<style>
  .methods { display: grid; grid-template-columns: repeat(auto-fit, minmax(100px, 1fr)); gap: 8px; }
  .m { display: flex; flex-direction: column; align-items: flex-start; gap: 3px; padding: 10px 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: inherit; font-size: 13px; font-weight: 600; text-align: left; }
  .m i { color: var(--muted); }
  .m .sub { color: var(--muted); font-weight: 500; font-size: 11px; }
  .m.on { border-color: var(--accent); background: var(--accent-soft); }
  .m.on i { color: var(--accent); }
  .fin { display: flex; flex-direction: column; gap: 12px; }
  .field em { font-style: normal; color: var(--accent-2); margin-left: 6px; }
  input[type='range'] { width: 100%; accent-color: var(--accent); }
  .terms { display: flex; gap: 6px; flex-wrap: wrap; }
  .pill { height: 28px; padding: 0 12px; border-radius: 999px; border: 1px solid var(--line-3); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; }
  .pill.on { background: var(--accent-soft); border-color: var(--accent); color: var(--accent-2); }
  .quote { display: flex; flex-direction: column; gap: 6px; padding: 12px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line-2); }
  .quote.no { opacity: 0.7; }
  .q { display: flex; justify-content: space-between; font-size: 13px; color: var(--text-2); }
  .q.big { font-size: 15px; font-weight: 700; color: var(--text); padding: 6px 0; border-top: 1px solid var(--line-2); border-bottom: 1px solid var(--line-2); }
  .sum { display: flex; justify-content: space-between; align-items: baseline; padding-top: 10px; border-top: 1px solid var(--line-2); font-size: 14px; color: var(--text-2); }
  .sum .num { font-size: 22px; font-weight: 600; color: var(--accent-2); }
  .row { display: flex; justify-content: flex-end; gap: 8px; }
</style>
