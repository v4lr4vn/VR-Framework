<script>
  import { app, act, toast, refresh } from '../lib/store.svelte.js';
  import { call } from '../lib/api.js';
  import { money, until, date } from '../lib/format.js';
  import { reasonText, errorText } from '../lib/errors.js';
  import AmountInput from '../ui/AmountInput.svelte';
  import Modal from '../ui/Modal.svelte';

  let o = $derived(app.overview);
  let ls = $derived(o.settings.loans);
  let amount = $state('5000');
  let term = $state(null);
  let plate = $state('');
  let vehicles = $state([]);
  let quote = $state(null);
  let quoting = $state(false);
  let paying = $state(null);
  let payAmount = $state('');
  let confirm = $state(false);
  let timer;

  $effect(() => {
    if (term == null && ls.terms.length) term = ls.terms[Math.min(2, ls.terms.length - 1)];
  });

  $effect(() => {
    if (!ls.collateral) return;
    call('loans.vehicles').then((r) => { if (r.ok) vehicles = r.data; });
  });

  $effect(() => {
    const d = { amount: parseInt(amount, 10) || 0, term, plate };
    clearTimeout(timer);
    quoting = true;
    timer = setTimeout(async () => {
      const r = await call('loans.quote', d);
      quoting = false;
      if (r.ok) quote = r.data;
    }, 300);
  });

  let active = $derived(o.loans.filter((l) => l.status === 'active' || l.status === 'collections'));
  let past = $derived(o.loans.filter((l) => l.status === 'paid'));

  async function apply() {
    const r = await call('loans.apply', { amount: parseInt(amount, 10) || 0, term, plate });
    confirm = false;
    if (!r.ok) return toast(errorText(r.error), 'err');
    toast(`Approved. ${money(r.data.amount)} is in your personal account`, 'ok');
    refresh();
  }

  async function pay(e) {
    e.preventDefault();
    const r = await act('loans.pay', { loan: paying.id, amount: parseInt(payAmount, 10) || 0 }, (d) => (d.status === 'paid' ? 'Loan paid off' : 'Payment made'));
    if (r.ok) paying = null;
  }
  const progress = (l) => Math.round(((l.total + l.fees - l.remaining) / (l.total + l.fees)) * 100);
</script>

<div class="wrap">
  <div class="col">
    <div class="h"><h2>Loans</h2><span class="hint">Installments are taken from your personal account every {ls.intervalHours}h</span></div>
    {#if !active.length}
      <div class="empty box"><i class="fa-solid fa-hand-holding-dollar"></i>No active loans</div>
    {/if}
    {#each active as l (l.id)}
      <div class="loan box" class:bad={l.status === 'collections' || l.missed > 0}>
        <div class="lhead">
          <div>
            <span class="label">{l.kind === 'finance' ? 'Car finance' : 'Loan'} #{l.id}</span>
            <div class="lrem num">{money(l.remaining)} <span class="muted">left of {money(l.total + l.fees)}</span></div>
          </div>
          {#if l.status === 'collections'}
            <span class="chip danger"><i class="fa-solid fa-gavel"></i>In collections</span>
          {:else if l.missed > 0}
            <span class="chip warn"><i class="fa-solid fa-triangle-exclamation"></i>{l.missed} missed</span>
          {:else}
            <span class="chip ok"><i class="fa-solid fa-circle-check"></i>On track</span>
          {/if}
        </div>
        <div class="bar {l.status === 'collections' ? 'danger' : 'ok'}"><span style="width:{progress(l)}%"></span></div>
        <div class="facts">
          <div><span class="k">Installment</span><span class="v num">{money(l.installment)}</span></div>
          <div><span class="k">Next payment</span><span class="v">{l.status === 'active' ? until(l.nextDue) : '—'}</span></div>
          <div><span class="k">Paid</span><span class="v num">{l.paidCount}/{l.term}</span></div>
          <div><span class="k">Rate</span><span class="v num">{l.rate}%</span></div>
          {#if l.vehicle}<div><span class="k">Collateral</span><span class="v">{l.vehicle} <span class="num muted">{l.plate}</span></span></div>{/if}
        </div>
        {#if l.arrears > 0 && l.status === 'active'}
          <div class="notice danger"><i class="fa-solid fa-triangle-exclamation"></i><span>{money(l.arrears)} is overdue, including late fees. {l.defaultAfter - l.missed} more missed payment{l.defaultAfter - l.missed === 1 ? '' : 's'} and this loan goes to collections.</span></div>
        {/if}
        {#if l.status === 'active'}
          <div class="lacts">
            <button class="btn small" onclick={() => { paying = l; payAmount = String(Math.max(l.arrears, Math.min(l.installment, l.remaining))); }}><i class="fa-solid fa-money-bill-transfer"></i>Make a payment</button>
            <button class="btn small ghost" onclick={() => { paying = l; payAmount = String(l.remaining); }}>Pay off {money(l.remaining)}</button>
          </div>
        {:else}
          <p class="hint">Pay this off from the Debt section to close the case and get any held vehicles back.</p>
        {/if}
      </div>
    {/each}
    {#if past.length}
      <span class="label past">Recently paid</span>
      {#each past as l}
        <div class="prow"><i class="fa-solid fa-circle-check"></i><span>{l.kind === 'finance' ? 'Car finance' : 'Loan'} #{l.id}</span><span class="num muted">{money(l.principal)} borrowed</span><span class="muted">closed {date(l.closedAt)}</span></div>
      {/each}
    {/if}
  </div>

  <aside class="apply box">
    <div class="box-head"><h3>Apply for a loan</h3>{#if quote}<span class="chip">{quote.tier.label} credit</span>{/if}</div>
    <div class="box-body f">
      {#if !ls.enabled}
        <div class="notice"><i class="fa-solid fa-circle-info"></i><span>The bank is not lending right now.</span></div>
      {:else}
        <AmountInput bind:value={amount} label="How much?" quick={[2500, 5000, 10000, 25000]} />
        <div class="field">
          <span>Pay back over</span>
          <div class="terms">
            {#each ls.terms as t}
              <button type="button" class="pill" class:on={term === t} onclick={() => (term = t)}>{t} payments</button>
            {/each}
          </div>
        </div>
        {#if ls.collateral}
          <label class="field">
            <span>Secure it with a vehicle <em class="hint">optional</em></span>
            <select class="input" bind:value={plate}>
              <option value="">No collateral</option>
              {#each vehicles as v}
                <option value={v.plate} disabled={v.pledged || v.held}>{v.name} · {v.plate} · worth {money(v.value)}{v.pledged ? ' (already pledged)' : ''}</option>
              {/each}
            </select>
          </label>
        {/if}
        {#if quote}
          <div class="quote" class:no={!quote.approved}>
            <div class="qrow"><span>Rate</span><span class="num">{quote.rate}%{quote.collateral ? ' (secured)' : ''}</span></div>
            <div class="qrow"><span>Interest</span><span class="num">{money(quote.interest)}</span></div>
            <div class="qrow"><span>Total to repay</span><span class="num">{money(quote.total)}</span></div>
            <div class="qrow big"><span>{quote.term} payments of</span><span class="num">{money(quote.installment)}</span></div>
            <div class="qrow"><span>Your limit</span><span class="num">{money(quote.maxLoan)}</span></div>
          </div>
          {#if !quote.approved}
            <div class="notice danger"><i class="fa-solid fa-circle-xmark"></i><span>{quote.reasons.map(reasonText).join('. ')}.</span></div>
          {:else}
            <div class="notice ok"><i class="fa-solid fa-circle-check"></i><span>Pre-approved. Missing {ls.defaultAfter} payments in a row sends the loan to collections{quote.collateral ? ' and the vehicle can be repossessed' : ''}.</span></div>
          {/if}
        {/if}
        <button class="btn primary" disabled={quoting || !quote?.approved || app.busy} onclick={() => (confirm = true)}><i class="fa-solid fa-file-signature"></i>Take the loan</button>
      {/if}
    </div>
  </aside>
</div>

{#if confirm && quote}
  <Modal title="Confirm loan" icon="fa-file-signature" onclose={() => (confirm = false)} width={420}>
    <p class="msg">Borrow <strong class="num">{money(quote.amount)}</strong> and repay <strong class="num">{money(quote.total)}</strong> in {quote.term} payments of <strong class="num">{money(quote.installment)}</strong>, one every {quote.intervalHours} hours, from your personal account.</p>
    <div class="row"><button class="btn ghost" onclick={() => (confirm = false)}>Not now</button><button class="btn primary" onclick={apply}>Sign and take the money</button></div>
  </Modal>
{/if}

{#if paying}
  <Modal title="Loan #{paying.id} payment" icon="fa-money-bill-transfer" onclose={() => (paying = null)} width={420}>
    <form class="f" onsubmit={pay}>
      <AmountInput bind:value={payAmount} max={paying.remaining} quick={[paying.installment]} autofocus={true} />
      <p class="hint">Paid from your personal account. Paying off early gives your credit score a boost.</p>
      <div class="row"><button type="button" class="btn ghost" onclick={() => (paying = null)}>Cancel</button><button class="btn primary" disabled={app.busy || !(parseInt(payAmount, 10) > 0)}>Pay {money(Math.min(parseInt(payAmount, 10) || 0, paying.remaining))}</button></div>
    </form>
  </Modal>
{/if}

<style>
  .wrap { display: grid; grid-template-columns: 1fr 360px; gap: 20px; align-items: start; }
  .col { display: flex; flex-direction: column; gap: 12px; }
  .h { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
  h2 { font-size: 20px; font-weight: 700; }
  .loan { padding: 14px; display: flex; flex-direction: column; gap: 12px; }
  .loan.bad { border-color: var(--danger-line); }
  .lhead { display: flex; justify-content: space-between; align-items: flex-start; }
  .lrem { font-size: 22px; font-weight: 600; margin-top: 2px; }
  .lrem .muted { font-size: 13px; font-weight: 400; }
  .facts { display: flex; flex-wrap: wrap; gap: 8px 24px; }
  .facts div { display: flex; flex-direction: column; }
  .k { font-size: 10px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); font-weight: 600; }
  .v { font-size: 14px; font-weight: 600; }
  .lacts { display: flex; gap: 8px; }
  .past { margin-top: 8px; }
  .prow { display: flex; align-items: center; gap: 12px; padding: 8px 10px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); font-size: 13px; }
  .prow i { color: var(--ok); }
  .apply { position: sticky; top: 0; }
  .f { display: flex; flex-direction: column; gap: 14px; }
  .terms { display: flex; gap: 6px; flex-wrap: wrap; }
  .pill { height: 30px; padding: 0 12px; border-radius: 999px; border: 1px solid var(--line-3); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; }
  .pill.on { background: var(--accent-soft); border-color: var(--accent); color: var(--accent-2); }
  em.hint { font-style: normal; font-weight: 400; }
  .quote { display: flex; flex-direction: column; gap: 6px; padding: 12px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line-2); }
  .quote.no { opacity: 0.7; }
  .qrow { display: flex; justify-content: space-between; font-size: 13px; color: var(--text-2); }
  .qrow.big { font-size: 15px; font-weight: 700; color: var(--text); padding: 6px 0; border-top: 1px solid var(--line-2); border-bottom: 1px solid var(--line-2); }
  .row { display: flex; justify-content: flex-end; gap: 8px; }
  .msg { font-size: 14px; color: var(--text-2); line-height: 1.55; }
</style>
