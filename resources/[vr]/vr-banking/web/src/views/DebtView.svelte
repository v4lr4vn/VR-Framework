<script>
  import { app, act } from '../lib/store.svelte.js';
  import { money, ago } from '../lib/format.js';
  import AmountInput from '../ui/AmountInput.svelte';
  import Modal from '../ui/Modal.svelte';

  let o = $derived(app.overview);
  let paying = $state(null);
  let method = $state('bank');
  let amount = $state('');
  let personal = $derived(o.accounts.find((a) => a.type === 'personal'));

  async function pay(e) {
    e.preventDefault();
    const n = parseInt(amount, 10) || 0;
    const r = await act('debts.pay', { case: paying.id, method, amount: n >= paying.amount ? 'full' : n }, (d) => (d.cleared ? `Debt cleared${d.released?.length ? `. Released ${d.released.join(', ')}` : ''}` : `Paid. ${money(d.left)} left`));
    if (r.ok) paying = null;
  }
</script>

<div class="h"><h2>Debt</h2><span class="hint">Money owed to {o.bank} collections</span></div>

{#if !o.debts.length && !o.held.length}
  <div class="empty box"><i class="fa-solid fa-circle-check"></i>You have no debt. Keep it that way.</div>
{/if}

{#each o.debts as d (d.id)}
  <div class="case box">
    <div class="chead">
      <div>
        <span class="label">Case #{d.id}{d.loanId ? ` · loan #${d.loanId}` : ''}</span>
        <div class="owed num">{money(d.amount)}</div>
        <span class="muted small">Opened {ago(d.created)}{d.amount > d.original ? ` · includes ${money(d.amount - d.original)} in fees` : ''}</span>
      </div>
      <button class="btn primary" onclick={() => { paying = d; amount = String(d.amount); method = 'bank'; }}><i class="fa-solid fa-hand-holding-dollar"></i>Pay now</button>
    </div>
    <div class="notice danger"><i class="fa-solid fa-truck-pickup"></i><span>Debt collectors can repossess your vehicles while this is open. Paying in full releases anything they have taken and improves your credit score.</span></div>
    {#if d.vehicles?.some((v) => v.tracked)}
      <div class="notice warn"><i class="fa-solid fa-tower-broadcast"></i><span>The bank tracker in your collateral car is on, so collectors can see where it is. It can't go back in a garage until the debt is paid.</span></div>
    {/if}
    {#if d.vehicles?.length}
      <div class="veh">
        {#each d.vehicles as v}
          <div class="vrow">
            <i class="fa-solid fa-car"></i>
            <span>{v.name}</span>
            <span class="num plate">{v.plate}</span>
            {#if v.held}<span class="chip danger">Held by the bank</span>{:else if v.tracked}<span class="chip danger"><i class="fa-solid fa-tower-broadcast"></i>Tracker on</span>{:else if v.collateral}<span class="chip warn">Collateral</span>{:else}<span class="chip">At risk</span>{/if}
          </div>
        {/each}
      </div>
    {/if}
  </div>
{/each}

{#if o.held.length && !o.debts.length}
  <div class="box">
    <div class="box-head"><h3>Held vehicles</h3></div>
    <div class="box-body veh">
      {#each o.held as v}
        <div class="vrow"><i class="fa-solid fa-car"></i><span>{v.name}</span><span class="num plate">{v.plate}</span><span class="chip danger">Held</span></div>
      {/each}
    </div>
  </div>
{/if}

{#if paying}
  <Modal title="Pay case #{paying.id}" icon="fa-hand-holding-dollar" onclose={() => (paying = null)} width={440}>
    <form class="f" onsubmit={pay}>
      <div class="methods">
        <button type="button" class="m" class:on={method === 'bank'} onclick={() => (method = 'bank')}>
          <i class="fa-solid fa-building-columns"></i><span>Personal account</span><span class="num">{money(personal?.balance)}</span>
        </button>
        <button type="button" class="m" class:on={method === 'cash'} onclick={() => (method = 'cash')}>
          <i class="fa-solid fa-money-bill-wave"></i><span>Cash</span><span class="num">{money(o.me.cash)}</span>
        </button>
      </div>
      <AmountInput bind:value={amount} max={paying.amount} quick={[]} />
      <p class="hint">Part payments lower the debt, but vehicles are only released once it is fully paid.</p>
      <div class="row"><button type="button" class="btn ghost" onclick={() => (paying = null)}>Cancel</button><button class="btn primary" disabled={app.busy || !(parseInt(amount, 10) > 0)}>Pay {money(Math.min(parseInt(amount, 10) || 0, paying.amount))}</button></div>
    </form>
  </Modal>
{/if}

<style>
  .h { display: flex; align-items: baseline; gap: 10px; margin-bottom: 14px; }
  h2 { font-size: 20px; font-weight: 700; }
  .case { padding: 14px; display: flex; flex-direction: column; gap: 12px; border-color: var(--danger-line); margin-bottom: 12px; }
  .chead { display: flex; justify-content: space-between; align-items: flex-start; }
  .owed { font-size: 30px; font-weight: 600; color: var(--danger-text); }
  .small { font-size: 12px; }
  .veh { display: flex; flex-direction: column; gap: 6px; }
  .vrow { display: grid; grid-template-columns: 18px 1fr 100px auto; align-items: center; gap: 10px; padding: 8px 10px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line-2); font-size: 13px; }
  .vrow i { color: var(--muted); }
  .plate { color: var(--accent-2); }
  .f { display: flex; flex-direction: column; gap: 14px; }
  .methods { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .m { display: flex; flex-direction: column; align-items: flex-start; gap: 3px; padding: 10px 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: inherit; font-size: 13px; font-weight: 600; text-align: left; }
  .m i { color: var(--muted); }
  .m .num { color: var(--muted); font-weight: 500; font-size: 12px; }
  .m.on { border-color: var(--accent); background: var(--accent-soft); }
  .m.on i { color: var(--accent); }
  .row { display: flex; justify-content: flex-end; gap: 8px; }
</style>
