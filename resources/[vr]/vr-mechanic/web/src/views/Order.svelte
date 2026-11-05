<script>
  import { call, nui, money, errorText } from '../lib/api.js';

  let { o, onclose } = $props();

  const WORK = { engine: 'fa-gears', paint: 'fa-spray-can', wheel: 'fa-circle-dot', under: 'fa-screwdriver-wrench', body: 'fa-car-side', glass: 'fa-window-maximize', rear: 'fa-tag', lights: 'fa-lightbulb' };
  const STATUS = {
    open: ['Waiting for a mechanic', 'info'],
    billed: ['Waiting for payment', 'warn'],
    paid: ['Paid, being fitted', 'accent'],
    done: ['Finished', 'ok'],
    cancelled: ['Cancelled', 'danger'],
    expired: ['Expired', 'danger'],
  };

  let order = $state(o);
  let busy = $state(false);
  let err = $state('');
  let waiting = $state(o.status === 'billed');

  let mech = $derived(order.role === 'mechanic');
  let done = $derived(order.tasks.filter((t) => t.done).length);
  let left = $derived(order.tasks.length - done);
  let status = $derived(STATUS[order.status] || [order.status, 'info']);
  let pct = $derived(order.tasks.length ? Math.round((done / order.tasks.length) * 100) : 0);
  let minutes = $derived(order.tasks.filter((t) => !t.done).reduce((s, t) => s + (t.seconds || 0), 0));

  async function bill() {
    if (busy) return;
    busy = true;
    err = '';
    const r = await call('order.bill', { id: order.id });
    busy = false;
    if (!r.ok) return (err = errorText(r.error));
    order.status = 'billed';
    waiting = true;
  }

  async function cancel() {
    if (busy) return;
    busy = true;
    err = '';
    const r = await call('order.cancel', { id: order.id });
    busy = false;
    if (!r.ok) return (err = errorText(r.error));
    order = r.data;
  }

  const fit = (task, all = false) => nui('fit', { id: order.id, task, all });
</script>

<section class="ord card" aria-label="Order {order.id}">
  <header>
    <span class="logo"><i class="fa-solid fa-clipboard-list"></i></span>
    <div class="title">
      <h1>Order #{order.id}</h1>
      <p class="sub">{order.workshop || 'Workshop'}{order.source === 'mechanic' ? ' · Booked by a mechanic' : ''}</p>
    </div>
    <span class="chip {status[1]}">{status[0]}</span>
    {#if mech}<button class="x" onclick={() => nui('openBoard')} aria-label="Back to work orders" title="All work orders"><i class="fa-solid fa-list"></i></button>{/if}
    <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
  </header>

  <div class="body">
    <div class="veh">
      <div class="vi"><i class="fa-solid fa-car-side"></i></div>
      <div class="vm">
        <strong>{order.vehicle || 'Vehicle'}</strong>
        <span class="hint">For {order.customer || 'a customer'}{order.mechanic ? ` · ${order.mechanic}` : ''}</span>
      </div>
      <span class="plate num">{order.plate}</span>
    </div>

    {#if order.status === 'paid' || order.status === 'done'}
      <div class="prog">
        <div class="bar ok"><span style="width:{pct}%"></span></div>
        <span class="num">{done}/{order.tasks.length}</span>
      </div>
    {/if}

    <div class="tasks scroll">
      {#each order.tasks as t (t.id)}
        <div class="task" class:done={t.done}>
          <span class="ti"><i class="fa-solid {t.done ? 'fa-check' : WORK[t.work] || 'fa-wrench'}"></i></span>
          <div class="tm">
            <span class="tl">{t.label}</span>
            <span class="hint num">{money(t.price)}{!t.done && t.seconds ? ` · ${t.seconds}s` : ''}</span>
          </div>
          {#if t.done}
            <span class="chip ok">Fitted</span>
          {:else if mech && order.status === 'paid'}
            <button class="btn small" onclick={() => fit(t.id)}><i class="fa-solid fa-wrench"></i>Fit</button>
          {:else}
            <span class="chip">To do</span>
          {/if}
        </div>
      {/each}
    </div>

    <div class="sum"><span>Total</span><span class="num">{money(order.total)}</span></div>

    {#if mech}
      {#if order.status === 'open'}
        <div class="notice"><i class="fa-solid fa-circle-info"></i><span>Bring the car into the workshop. Send the bill when {order.customer || 'the customer'} is here. You can fit the parts once they pay.</span></div>
      {:else if order.status === 'billed' || waiting}
        <div class="notice warn"><i class="fa-solid fa-hourglass-half"></i><span>Waiting for {order.customer || 'the customer'} to pay.</span></div>
      {:else if order.status === 'paid'}
        <div class="notice ok"><i class="fa-solid fa-circle-check"></i><span>Paid. Stand by the car and fit each part. About {Math.ceil(minutes / 60)} min of work left.</span></div>
      {:else if order.status === 'done'}
        <div class="notice ok"><i class="fa-solid fa-flag-checkered"></i><span>Everything is fitted.</span></div>
      {/if}
    {:else}
      {#if order.status === 'open'}
        <div class="notice"><i class="fa-solid fa-circle-info"></i><span>Hand this sheet to a mechanic and bring the car to the workshop. You pay when they start the work.</span></div>
      {:else if order.status === 'billed'}
        <div class="notice warn"><i class="fa-solid fa-file-invoice-dollar"></i><span>A mechanic sent you the bill. Pay it to get the work started.</span></div>
      {:else if order.status === 'paid'}
        <div class="notice ok"><i class="fa-solid fa-screwdriver-wrench"></i><span>Paid. The mechanic is fitting your parts: {done} of {order.tasks.length} done.</span></div>
      {:else if order.status === 'done'}
        <div class="notice ok"><i class="fa-solid fa-flag-checkered"></i><span>Your car is finished.</span></div>
      {/if}
    {/if}
    {#if order.status === 'cancelled' || order.status === 'expired'}
      <div class="notice danger"><i class="fa-solid fa-ban"></i><span>This order is {order.status}. Nothing was charged.</span></div>
    {/if}
    {#if err}<div class="notice danger"><i class="fa-solid fa-circle-exclamation"></i><span>{err}</span></div>{/if}
  </div>

  <footer>
    {#if mech}
      {#if order.status === 'open'}
        <button class="btn primary" disabled={busy} onclick={bill}><i class="fa-solid fa-file-invoice-dollar"></i>Send bill <span class="num">{money(order.total)}</span></button>
      {:else if order.status === 'paid'}
        <button class="btn primary" disabled={left === 0} onclick={() => fit(null, true)}><i class="fa-solid fa-screwdriver-wrench"></i>Fit everything</button>
      {:else}
        <button class="btn ghost" onclick={onclose}>Close</button>
      {/if}
    {:else}
      {#if order.status === 'open'}
        <button class="btn danger" disabled={busy} onclick={cancel}><i class="fa-solid fa-ban"></i>Cancel order</button>
      {/if}
      <button class="btn ghost" onclick={onclose}>Close</button>
    {/if}
  </footer>
</section>

<style>
  .ord { width: 540px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 10px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 15px; }
  .title { flex: 1; min-width: 0; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  header .chip { height: 24px; font-size: 11px; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--line-3); background: var(--panel-2); }
  .body { padding: 16px; display: flex; flex-direction: column; gap: 12px; min-height: 0; }
  .veh { display: flex; align-items: center; gap: 12px; padding: 12px; border-radius: var(--radius-lg); background: var(--bg-2); border: 1px solid var(--line-2); }
  .vi { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--panel-2); color: var(--muted); }
  .vm { flex: 1; display: flex; flex-direction: column; gap: 1px; }
  .vm strong { font-size: 15px; }
  .plate { padding: 3px 8px; border-radius: 4px; background: #e9eef4; color: #18212d; font-size: 12px; font-weight: 600; letter-spacing: 0.1em; border: 2px solid #9fb0c4; }
  .prog { display: grid; grid-template-columns: 1fr auto; align-items: center; gap: 10px; font-size: 12px; color: var(--muted); }
  .tasks { display: flex; flex-direction: column; gap: 6px; max-height: 300px; padding-right: 4px; }
  .task { display: grid; grid-template-columns: 34px 1fr auto; align-items: center; gap: 12px; padding: 8px 10px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); }
  .task.done { opacity: 0.7; }
  .ti { width: 34px; height: 34px; border-radius: var(--radius); display: grid; place-items: center; background: var(--panel-2); color: var(--accent); font-size: 13px; }
  .task.done .ti { background: var(--ok-bg); color: var(--ok); }
  .tm { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
  .tl { font-size: 13px; font-weight: 700; }
  .task .chip { height: 22px; }
  .sum { display: flex; justify-content: space-between; align-items: baseline; padding-top: 10px; border-top: 1px solid var(--line-2); font-size: 14px; font-weight: 600; color: var(--text-2); }
  .sum .num { font-size: 22px; color: var(--accent-2); }
  footer { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--line-2); }
  footer .btn.primary { height: 38px; }
</style>
