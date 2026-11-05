<script>
  import Modal from '../ui/Modal.svelte';
  import { app, act, go } from '../lib/store.svelte.js';

  let { onclose } = $props();
  let kind = $state('shared');
  let label = $state('');
  let s = $derived(app.overview?.settings);
  let savingsCount = $derived(app.overview ? app.overview.accounts.filter((a) => a.type === 'savings').length : 0);
  let sharedCount = $derived(app.overview ? app.overview.accounts.filter((a) => a.type === 'shared' && a.myRole === 'owner').length : 0);

  async function submit(e) {
    e.preventDefault();
    const r = kind === 'savings' ? await act('savings.open', {}, 'Savings account opened') : await act('shared.create', { label }, 'Shared account opened');
    if (r.ok) {
      go('account', r.data.id);
      onclose();
    }
  }
</script>

<Modal title="Open an account" icon="fa-plus" {onclose} width={480}>
  <form class="f" onsubmit={submit}>
    <div class="opts">
      <button type="button" class="opt" class:on={kind === 'shared'} onclick={() => (kind = 'shared')}>
        <i class="fa-solid fa-users"></i>
        <strong>Shared account</strong>
        <span>Pool money with friends, family or a crew. You choose who can withdraw.</span>
        <em class="num">{sharedCount}/{s?.limits.maxShared} used</em>
      </button>
      <button type="button" class="opt" class:on={kind === 'savings'} onclick={() => (kind = 'savings')}>
        <i class="fa-solid fa-piggy-bank"></i>
        <strong>Savings account</strong>
        <span>Earns {s?.savings.rate}% every {s?.savings.periodHours}h on balances over ${s?.savings.minBalance.toLocaleString('en-US')}.</span>
        <em class="num">{savingsCount}/{s?.limits.maxSavings} used</em>
      </button>
    </div>
    {#if kind === 'shared'}
      <label class="field">
        <span>Account name</span>
        <input class="input" maxlength="32" placeholder="e.g. House fund" bind:value={label} />
      </label>
    {/if}
    <div class="row">
      <button type="button" class="btn ghost" onclick={onclose}>Cancel</button>
      <button type="submit" class="btn primary" disabled={app.busy || (kind === 'shared' && label.trim().length < 2)}>Open account</button>
    </div>
  </form>
</Modal>

<style>
  .f { display: flex; flex-direction: column; gap: 14px; }
  .opts { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .opt { display: flex; flex-direction: column; align-items: flex-start; gap: 6px; padding: 14px; border-radius: var(--radius-lg); border: 1px solid var(--line-2); background: var(--panel); color: inherit; text-align: left; }
  .opt i { font-size: 18px; color: var(--muted); }
  .opt strong { font-size: 14px; }
  .opt span { font-size: 12px; color: var(--muted); line-height: 1.4; }
  .opt em { font-style: normal; font-size: 11px; color: var(--faint); margin-top: 2px; }
  .opt:hover { border-color: var(--line-3); }
  .opt.on { border-color: var(--accent); background: var(--accent-soft); }
  .opt.on i { color: var(--accent); }
  .row { display: flex; justify-content: flex-end; gap: 8px; }
</style>
