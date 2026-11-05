<script>
  import Modal from '../ui/Modal.svelte';
  import AmountInput from '../ui/AmountInput.svelte';
  import { app, act } from '../lib/store.svelte.js';
  import { call } from '../lib/api.js';
  import { money, acct } from '../lib/format.js';

  let { account, mode, onclose } = $props();
  let amount = $state('');
  let to = $state('');
  let note = $state('');
  let target = $state(null);
  let lookupErr = $state('');
  let timer;

  const titles = { deposit: 'Deposit cash', withdraw: 'Withdraw cash', transfer: 'Send money' };
  const icons = { deposit: 'fa-arrow-down', withdraw: 'fa-arrow-up', transfer: 'fa-arrow-right-arrow-left' };
  let mine = $derived(app.overview ? app.overview.accounts.filter((a) => a.id !== account.id && a.rights.deposit) : []);
  let max = $derived(mode === 'deposit' ? app.overview?.me.cash : account.balance);
  let n = $derived(parseInt(amount, 10) || 0);
  let clean = $derived(to.replace(/[\s-]/g, ''));

  $effect(() => {
    const v = clean;
    clearTimeout(timer);
    target = null;
    lookupErr = '';
    if (mode !== 'transfer' || v.length < 6) return;
    timer = setTimeout(async () => {
      const r = await call('lookup', { number: v });
      if (clean !== v) return;
      if (r.ok) target = r.data;
      else lookupErr = 'No account with that number';
    }, 350);
  });

  async function submit(e) {
    e.preventDefault();
    if (!n) return;
    let r;
    if (mode === 'transfer') r = await act('transfer', { account: account.id, to: clean, amount: n, note }, `Sent ${money(n)}`);
    else r = await act(mode, { account: account.id, amount: n }, mode === 'deposit' ? `Deposited ${money(n)}` : `Withdrew ${money(n)}`);
    if (r.ok) onclose(true);
  }
</script>

<Modal title={titles[mode]} icon={icons[mode]} onclose={() => onclose(false)} width={460}>
  <form class="f" onsubmit={submit}>
    <div class="from">
      <span class="label">{mode === 'deposit' ? 'Into' : 'From'}</span>
      <div class="acc"><strong>{account.label}</strong><span class="num">{acct(account.number)}</span><span class="num bal">{money(account.balance)}</span></div>
    </div>

    {#if mode === 'transfer'}
      <label class="field">
        <span>To account number</span>
        <input class="input num" placeholder="40 0000 0000" maxlength="14" bind:value={to} />
      </label>
      {#if mine.length}
        <div class="mine">
          {#each mine as a}
            <button type="button" class="btn small ghost" onclick={() => (to = a.number)}>{a.label}</button>
          {/each}
        </div>
      {/if}
      {#if target}
        <div class="notice ok"><i class="fa-solid fa-circle-check"></i><span>{target.kind} account · <strong>{target.name}</strong></span></div>
      {:else if lookupErr}
        <div class="notice danger"><i class="fa-solid fa-circle-exclamation"></i><span>{lookupErr}</span></div>
      {/if}
    {/if}

    <AmountInput bind:value={amount} {max} autofocus={mode !== 'transfer'} quick={mode === 'transfer' ? [100, 500, 1000, 5000] : [100, 500, 1000, 2500]} />

    {#if mode === 'transfer'}
      <label class="field">
        <span>Reference <em class="hint">optional</em></span>
        <input class="input" maxlength="64" placeholder="What is it for?" bind:value={note} />
      </label>
    {/if}

    <div class="sum">
      <span class="muted">{mode === 'deposit' ? 'Cash on you' : 'Available'}</span>
      <span class="num">{money(max)}</span>
    </div>

    <div class="row">
      <button type="button" class="btn ghost" onclick={() => onclose(false)}>Cancel</button>
      <button type="submit" class="btn primary" disabled={app.busy || !n || n > (max ?? 0) || (mode === 'transfer' && !target)}>
        {mode === 'deposit' ? 'Deposit' : mode === 'withdraw' ? 'Withdraw' : 'Send'} {n ? money(n) : ''}
      </button>
    </div>
  </form>
</Modal>

<style>
  .f { display: flex; flex-direction: column; gap: 14px; }
  .from { display: flex; flex-direction: column; gap: 6px; }
  .acc { display: flex; align-items: center; gap: 10px; padding: 10px 12px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line-2); font-size: 13px; }
  .acc span { color: var(--faint); font-size: 12px; }
  .acc .bal { margin-left: auto; color: var(--text-2); font-size: 13px; }
  .mine { display: flex; flex-wrap: wrap; gap: 6px; margin-top: -6px; }
  em.hint { font-style: normal; font-weight: 400; margin-left: 4px; }
  .sum { display: flex; justify-content: space-between; font-size: 13px; padding-top: 10px; border-top: 1px solid var(--line-2); }
  .row { display: flex; justify-content: flex-end; gap: 8px; }
</style>
